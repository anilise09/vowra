import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { audit, fail, noContent, requireAccount, requireModerator, type Services } from '../context.js';
import { hashToken, newToken } from '../crypto.js';
import type { Db } from '../db.js';
import { photoRules, processPhoto, rejectReasons, sniffMime } from '../media.js';
import { openConversation } from './chat.js';
import { isEligible } from './discovery.js';
import { requireRecentSignIn } from './lifecycle.js';

const uuid = z.string().uuid();
const uploadBody = z
  .object({
    client_upload_id: z.string().min(1).max(100),
    mime_type: z.enum(photoRules.mimeTypes),
    byte_length: z.number().int().min(1).max(photoRules.maxBytes),
    sha256: z.string().regex(/^[a-f0-9]{64}$/),
  })
  .strict();
const orderBody = z.object({ photo_ids: z.array(uuid).max(photoRules.maxPhotos) }).strict();
const photoDecision = z
  .object({ outcome: z.enum(['approved', 'rejected']), reason: z.enum(rejectReasons).optional() })
  .strict();

const iso = (d: Date | string | null) => (d == null ? null : new Date(d).toISOString());

/**
 * Approved profile photos for a set of people, as short-lived links bound to
 * the viewer. Used by Discover, Likes you and matches.
 */
export async function photosFor(
  services: Services,
  viewer: string,
  owners: string[],
): Promise<Map<string, { photo_id: string; url: string }[]>> {
  const out = new Map<string, { photo_id: string; url: string }[]>();
  if (owners.length === 0) return out;
  const rows = await services.db.query<{ id: string; owner: string }>(
    `SELECT id, owner FROM media WHERE owner = ANY($1::uuid[]) AND state = 'approved'
       AND audience = 'profile'
     ORDER BY owner, position, created_at`,
    [owners],
  );
  const now = services.clock.now();
  for (const row of rows) {
    const list = out.get(row.owner) ?? [];
    list.push({ photo_id: row.id, url: services.grants.url('view', row.id, viewer, now) });
    out.set(row.owner, list);
  }
  return out;
}

/** Whether [viewer] may see [owner]'s approved photos right now. */
async function maySee(db: Db, viewer: string, owner: string): Promise<boolean> {
  if (viewer === owner) return true;
  if (await isEligible(db, viewer, owner)) return true;
  // Matches keep seeing each other while the conversation is open.
  const [low, high] = viewer < owner ? [viewer, owner] : [owner, viewer];
  const open = await db.query(
    `SELECT 1 FROM matches m JOIN accounts a ON a.id = $3
     WHERE m.account_low = $1 AND m.account_high = $2 AND m.status = 'active'
       AND a.lifecycle IN ('active','paused')
       AND NOT EXISTS (SELECT 1 FROM blocks b WHERE (b.blocker = $1 AND b.blocked = $2)
                                              OR (b.blocker = $2 AND b.blocked = $1))`,
    [low, high, owner],
  );
  return open.length > 0;
}

export function mediaRoutes(app: FastifyInstance, services: Services) {
  const { db, clock } = services;

  // Photo bytes arrive as the raw body of the upload request only.
  app.addContentTypeParser(
    [...photoRules.mimeTypes],
    { parseAs: 'buffer', bodyLimit: photoRules.maxBytes },
    (_request, body, done) => done(null, body),
  );

  /** Asks to upload one profile photo: returns a single-use, short-lived grant. */
  app.post('/v1/me/photos', async (request) => {
    const me = requireAccount(request);
    if (me.lifecycle === 'suspended') fail(409, 'account_suspended');
    if (me.lifecycle === 'deletion_scheduled') fail(409, 'deletion_scheduled');
    const body = uploadBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const req = body.data!;
    const profile = await db.query('SELECT 1 FROM profiles WHERE account_id = $1', [me.id]);
    if (profile.length === 0) fail(409, 'profile_incomplete');
    const now = clock.now();
    const token = newToken();
    const expires = new Date(now.getTime() + photoRules.uploadGrantSeconds * 1000);
    const [existing] = await db.query<{ id: string; state: string }>(
      'SELECT id, state FROM media WHERE owner = $1 AND client_upload_id = $2',
      [me.id, req.client_upload_id],
    );
    let id: string;
    if (existing) {
      // Asking again for the same upload refreshes its grant; it never re-opens a finished one.
      if (existing.state !== 'awaiting_upload') fail(409, 'already_uploaded');
      id = existing.id;
      await db.query('UPDATE media SET grant_hash = $2, grant_expires_at = $3 WHERE id = $1', [
        id,
        hashToken(token),
        expires,
      ]);
    } else {
      const [counts] = await db.query<{ kept: number; today: number }>(
        `SELECT count(*) FILTER (WHERE state <> 'rejected' AND audience = 'profile')::int AS kept,
                count(*) FILTER (WHERE created_at > $2)::int AS today
         FROM media WHERE owner = $1`,
        [me.id, new Date(now.getTime() - 24 * 60 * 60 * 1000)],
      );
      if ((counts?.kept ?? 0) >= photoRules.maxPhotos) fail(409, 'photo_limit');
      if ((counts?.today ?? 0) >= photoRules.uploadsPerDay) fail(429, 'upload_limit');
      id = crypto.randomUUID();
      await db.query(
        `INSERT INTO media (id, owner, state, client_upload_id, mime_type, byte_length, sha256,
                            grant_hash, grant_expires_at, position, created_at)
         VALUES ($1, $2, 'awaiting_upload', $3, $4, $5, $6, $7, $8,
                 (SELECT COALESCE(max(position) + 1, 0) FROM media WHERE owner = $2), $9)`,
        [id, me.id, req.client_upload_id, req.mime_type, req.byte_length, req.sha256,
         hashToken(token), expires, now],
      );
    }
    return {
      photo_id: id,
      upload_url: `/v1/uploads/${id}?grant=${token}`,
      expires_at: expires.toISOString(),
    };
  });

  /** Asks to send a photo in a conversation; the receiver must allow photos. */
  app.post('/v1/matches/:matchId/photos', async (request) => {
    const me = requireAccount(request);
    if (me.lifecycle === 'suspended') fail(409, 'account_suspended');
    const body = uploadBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const req = body.data!;
    const match = await openConversation(db, me.id, (request.params as { matchId: string }).matchId);
    const consent = await db.query('SELECT 1 FROM photo_consent WHERE match_id = $1 AND account_id = $2', [
      match.id,
      match.peer,
    ]);
    if (consent.length === 0) fail(409, 'photos_not_allowed');
    const now = clock.now();
    const [today] = await db.query<{ n: number }>(
      'SELECT count(*)::int AS n FROM media WHERE owner = $1 AND created_at > $2',
      [me.id, new Date(now.getTime() - 24 * 60 * 60 * 1000)],
    );
    if ((today?.n ?? 0) >= photoRules.uploadsPerDay) fail(429, 'upload_limit');
    const token = newToken();
    const expires = new Date(now.getTime() + photoRules.uploadGrantSeconds * 1000);
    const id = crypto.randomUUID();
    await db.query(
      `INSERT INTO media (id, owner, audience, match_id, state, client_upload_id, mime_type, byte_length,
                          sha256, grant_hash, grant_expires_at, created_at)
       VALUES ($1, $2, 'conversation', $3, 'awaiting_upload', $4, $5, $6, $7, $8, $9, $10)`,
      [id, me.id, match.id, req.client_upload_id, req.mime_type, req.byte_length, req.sha256,
       hashToken(token), expires, now],
    );
    return { photo_id: id, upload_url: `/v1/uploads/${id}?grant=${token}`, expires_at: expires.toISOString() };
  });

  /**
   * The photo bytes, with the grant. Size, type and hash must match what was
   * asked for; the image is decoded safely and re-encoded without metadata.
   */
  app.put('/v1/uploads/:id', async (request) => {
    const id = uuid.safeParse((request.params as { id: string }).id);
    const grant = (request.query as { grant?: string }).grant;
    if (!id.success || !grant) fail(403, 'invalid_grant');
    const now = clock.now();
    const [row] = await db.query<{
      state: string;
      grant_hash: string | null;
      grant_expires_at: Date | null;
      mime_type: string;
      byte_length: number;
      sha256: string;
    }>(
      `SELECT state, grant_hash, grant_expires_at, mime_type, byte_length, sha256
       FROM media WHERE id = $1`,
      [id.data],
    );
    if (
      !row ||
      row.state !== 'awaiting_upload' ||
      !row.grant_hash ||
      row.grant_hash !== hashToken(grant!) ||
      !row.grant_expires_at ||
      new Date(row.grant_expires_at) < now
    ) {
      fail(403, 'invalid_grant');
    }
    const bytes = request.body;
    const contentType = String(request.headers['content-type'] ?? '').split(';')[0]!.trim();
    // The grant is spent on the first attempt, whatever happens next.
    await db.query('UPDATE media SET grant_hash = NULL WHERE id = $1', [id.data]);
    const reject = async (code: string, status = 422) => {
      await db.query("UPDATE media SET state = 'rejected', reject_reason = 'unreadable' WHERE id = $1", [
        id.data,
      ]);
      return fail(status, code);
    };
    if (!Buffer.isBuffer(bytes) || contentType !== row!.mime_type) return reject('wrong_type', 415);
    if (bytes.length !== row!.byte_length) return reject('size_mismatch');
    const { createHash } = await import('node:crypto');
    if (createHash('sha256').update(bytes).digest('hex') !== row!.sha256) return reject('hash_mismatch');
    if (sniffMime(bytes) !== row!.mime_type) return reject('wrong_type', 415);
    let processed;
    try {
      processed = await processPhoto(bytes);
    } catch {
      return reject('unreadable_image');
    }
    await services.media.put(id.data!, processed.bytes);
    await db.query(
      `UPDATE media SET state = 'pending_review', width = $2, height = $3 WHERE id = $1`,
      [id.data, processed.width, processed.height],
    );
    return { state: 'pending_review' };
  });

  /** Your own photos in order, with their review state. */
  app.get('/v1/me/photos', async (request) => {
    const me = requireAccount(request);
    const rows = await db.query<{
      id: string;
      state: string;
      reject_reason: string | null;
      position: number;
      created_at: Date;
    }>(
      `SELECT id, state, reject_reason, position, created_at FROM media
       WHERE owner = $1 AND state <> 'awaiting_upload' AND audience = 'profile'
       ORDER BY position, created_at`,
      [me.id],
    );
    const now = clock.now();
    return {
      photos: rows.map((r) => ({
        photo_id: r.id,
        state: r.state,
        reject_reason: r.reject_reason,
        created_at: iso(r.created_at),
        url: r.state === 'rejected' && !r.reject_reason ? null : services.grants.url('view', r.id, me.id, now),
      })),
      max_photos: photoRules.maxPhotos,
    };
  });

  app.delete('/v1/me/photos/:id', async (request, reply) => {
    const me = requireAccount(request);
    const id = uuid.safeParse((request.params as { id: string }).id);
    if (id.success) {
      const gone = await db.query<{ id: string }>(
        'DELETE FROM media WHERE id = $1 AND owner = $2 RETURNING id',
        [id.data, me.id],
      );
      if (gone.length > 0) await services.media.delete(id.data);
    }
    return noContent(reply);
  });

  /** New order for your photos; the first is the main one. */
  app.put('/v1/me/photos/order', async (request, reply) => {
    const me = requireAccount(request);
    const body = orderBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    await db.transaction(async (tx) => {
      for (const [position, id] of body.data!.photo_ids.entries()) {
        await tx.query('UPDATE media SET position = $3 WHERE id = $1 AND owner = $2', [id, me.id, position]);
      }
    });
    return noContent(reply);
  });

  /**
   * A photo, through its short-lived link. Access is checked again now: a
   * block, suspension or deletion takes effect even for an old link.
   */
  app.get('/v1/media/:id', async (request, reply) => {
    const q = request.query as { p?: string; v?: string; e?: string; s?: string };
    const id = uuid.safeParse((request.params as { id: string }).id);
    const viewer = uuid.safeParse(q.v);
    const now = clock.now();
    if (
      !id.success ||
      !viewer.success ||
      !q.p ||
      !q.s ||
      !services.grants.check(q.p, id.data, viewer.data, Number(q.e), q.s, now)
    ) {
      return fail(404, 'not_found');
    }
    const [row] = await db.query<{ owner: string; state: string; audience: string; match_id: string | null }>(
      'SELECT owner, state, audience, match_id FROM media WHERE id = $1',
      [id.data],
    );
    if (!row) return fail(404, 'not_found');
    let allowed = false;
    if (q.p === 'view' && row.audience === 'conversation') {
      // Only the two people in the match, while the conversation is open.
      try {
        await openConversation(db, viewer.data, row.match_id!);
        allowed = row.state === 'approved' || (viewer.data === row.owner && row.state !== 'awaiting_upload');
      } catch {
        allowed = false;
      }
    } else if (q.p === 'view') {
      allowed =
        viewer.data === row.owner
          ? row.state !== 'awaiting_upload'
          : row.state === 'approved' && (await maySee(db, viewer.data, row.owner));
    } else if (q.p === 'review') {
      const [mod] = await db.query<{ role: string }>('SELECT role FROM accounts WHERE id = $1', [viewer.data]);
      allowed = mod?.role === 'moderator' && row.state !== 'awaiting_upload' && viewer.data !== row.owner;
    }
    if (!allowed) return fail(404, 'not_found');
    const bytes = await services.media.get(id.data);
    if (!bytes) return fail(404, 'not_found');
    return reply
      .header('content-type', 'image/webp')
      .header('cache-control', 'private, max-age=300')
      .header('referrer-policy', 'no-referrer')
      .header('x-content-type-options', 'nosniff')
      .send(bytes);
  });

  /** Photos waiting for review, oldest first, never the moderator's own. */
  app.get('/v1/mod/photos', async (request) => {
    const mod = requireModerator(request);
    const rows = await db.query<{
      id: string;
      owner: string;
      display_name: string | null;
      created_at: Date;
      audience: string;
    }>(
      `SELECT m.id, m.owner, p.display_name, m.created_at, m.audience FROM media m
       LEFT JOIN profiles p ON p.account_id = m.owner
       WHERE m.state = 'pending_review' AND m.owner <> $1
       ORDER BY m.created_at LIMIT 50`,
      [mod.id],
    );
    const now = clock.now();
    return {
      photos: rows.map((r) => ({
        photo_id: r.id,
        account_id: r.owner,
        display_name: r.display_name,
        created_at: iso(r.created_at),
        context: r.audience === 'conversation' ? 'chat' : 'profile',
        url: services.grants.url('review', r.id, mod.id, now),
      })),
    };
  });

  app.post('/v1/mod/photos/:id/decision', async (request) => {
    const mod = requireModerator(request);
    await requireRecentSignIn(services, mod);
    const id = uuid.safeParse((request.params as { id: string }).id);
    const body = photoDecision.safeParse(request.body);
    if (!id.success || !body.success) fail(400, 'invalid_request');
    const { outcome, reason } = body.data!;
    if (outcome === 'rejected' && !reason) fail(400, 'invalid_request');
    const now = clock.now();
    const [row] = await db.query<{ owner: string; state: string; audience: string; match_id: string | null }>(
      'SELECT owner, state, audience, match_id FROM media WHERE id = $1',
      [id.data],
    );
    if (!row) fail(404, 'not_found');
    if (row!.owner === mod.id) fail(409, 'conflict_of_interest');
    if (row!.state !== 'pending_review') fail(409, 'already_decided');
    let peer: string | null = null;
    await db.transaction(async (tx) => {
      await tx.query(
        `UPDATE media SET state = $2, reject_reason = $3, decided_at = $4, decided_by = $5 WHERE id = $1`,
        [id.data, outcome, outcome === 'rejected' ? reason : null, now, mod.id],
      );
      if (outcome === 'approved' && row!.audience === 'conversation') {
        // Delivered only if the conversation is still open and photos still allowed.
        const [open] = await tx.query<{ peer: string }>(
          `SELECT CASE WHEN m.account_low = $2 THEN m.account_high ELSE m.account_low END AS peer
           FROM matches m WHERE m.id = $1 AND m.status = 'active'`,
          [row!.match_id, row!.owner],
        );
        const allowed = open
          ? await tx.query('SELECT 1 FROM photo_consent WHERE match_id = $1 AND account_id = $2', [
              row!.match_id,
              open.peer,
            ])
          : [];
        if (open && allowed.length > 0) {
          await tx.query(
            `INSERT INTO messages (id, match_id, author_id, body, created_at, media_id)
             VALUES ($1, $2, $3, '', $4, $5)`,
            [crypto.randomUUID(), row!.match_id, row!.owner, now, id.data],
          );
          peer = open.peer;
        }
      }
      await audit(tx, mod.id, `mod_photo_${outcome}`, now);
    });
    if (outcome === 'rejected') await services.media.delete(id.data!);
    services.nudges.publish(row!.owner, { kind: row!.match_id ? 'message' : 'match', match_id: row!.match_id ?? undefined });
    if (peer) services.nudges.publish(peer, { kind: 'message', match_id: row!.match_id! });
    return { state: outcome };
  });
}
