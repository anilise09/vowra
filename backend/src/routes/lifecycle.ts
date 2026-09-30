import type { FastifyInstance } from 'fastify';
import { endCalls } from '../calls.js';
import { audit, fail, noContent, requireAccount, type Account, type Services } from '../context.js';
import { cellKm } from '../location.js';
import { openCell } from './location.js';

/**
 * Deletion and data export need a sign-in within the reauthentication
 * window: a stolen or forgotten session on some device is never enough.
 */
export async function requireRecentSignIn(services: Services, account: Account) {
  const [family] = await services.db.query<{ created_at: Date }>(
    'SELECT created_at FROM session_families WHERE id = $1',
    [account.familyId],
  );
  const signedInAt = family ? new Date(family.created_at).getTime() : 0;
  if (services.clock.now().getTime() - signedInAt > services.reauthWindowSeconds * 1000) {
    fail(403, 'reauthentication_required');
  }
}

const iso = (d: Date | string | null) => (d == null ? null : new Date(d).toISOString());

/** Exports allowed per account in a rolling day. */
export const exportsPerDay = 5;

export function lifecycleRoutes(app: FastifyInstance, services: Services) {
  const { db, clock, sealer } = services;

  /**
   * A copy of what the server holds about the person asking. Other people's
   * messages, profiles and account IDs are left out, and so are internal
   * moderation notes; things kept only on the phone are not on the server.
   */
  app.get('/v1/me/export', async (request, reply) => {
    const account = requireAccount(request);
    await requireRecentSignIn(services, account);
    const me = account.id;
    const [recent] = await db.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM audit_events
       WHERE account_id = $1 AND kind = 'data_exported' AND created_at > $2`,
      [me, new Date(clock.now().getTime() - 24 * 60 * 60 * 1000)],
    );
    if ((recent?.n ?? 0) >= exportsPerDay) fail(429, 'rate_limited');
    const [acct] = await db.query<{
      email_sealed: string;
      created_at: Date;
      age_state: string;
      lifecycle: string;
      deletion_effective_at: Date | null;
      share_read_receipts: boolean;
    }>(
      `SELECT email_sealed, created_at, age_state, lifecycle, deletion_effective_at,
              share_read_receipts
       FROM accounts WHERE id = $1`,
      [me],
    );
    const [profile] = await db.query<Record<string, unknown>>(
      `SELECT display_name, relationship_intent, bio, interests, lifestyle, prompts, gender,
              show_me, show_gender, show_distance_band, call_ready_by_default, public_age,
              updated_at
       FROM profiles WHERE account_id = $1`,
      [me],
    );
    const [area] = await db.query<{ location_sealed: string | null; location_updated_at: Date | null }>(
      'SELECT location_sealed, location_updated_at FROM profiles WHERE account_id = $1',
      [me],
    );
    const cell = openCell(services, area?.location_sealed ?? null);
    const [suspension] = await db.query<{ suspended_at: Date | null; suspension_reason: string | null }>(
      'SELECT suspended_at, suspension_reason FROM accounts WHERE id = $1',
      [me],
    );
    // Their own words and the outcomes; never moderator notes or who decided.
    const appeals = await db.query<{
      message: string;
      state: string;
      created_at: Date;
      decided_at: Date | null;
    }>(
      'SELECT message, state, created_at, decided_at FROM appeals WHERE account_id = $1 ORDER BY created_at',
      [me],
    );
    const photoRows = await db.query<{ state: string; created_at: Date; decided_at: Date | null }>(
      `SELECT state, created_at, decided_at FROM media
       WHERE owner = $1 AND state <> 'awaiting_upload' ORDER BY position, created_at`,
      [me],
    );
    const swipes = await db.query<{ kind: string; created_at: Date }>(
      'SELECT kind, created_at FROM swipes WHERE from_account = $1 ORDER BY created_at',
      [me],
    );
    const matches = await db.query<{
      id: string;
      status: string;
      created_at: Date;
      peer_name: string | null;
    }>(
      `SELECT m.id, m.status, m.created_at, p.display_name AS peer_name
       FROM matches m
       LEFT JOIN profiles p ON p.account_id =
         CASE WHEN m.account_low = $1 THEN m.account_high ELSE m.account_low END
       WHERE m.account_low = $1 OR m.account_high = $1
       ORDER BY m.created_at`,
      [me],
    );
    const sent = await db.query<{ match_id: string; body: string; created_at: Date }>(
      'SELECT match_id, body, created_at FROM messages WHERE author_id = $1 ORDER BY created_at',
      [me],
    );
    const blocks = await db.query<{ created_at: Date }>(
      'SELECT created_at FROM blocks WHERE blocker = $1 ORDER BY created_at',
      [me],
    );
    const reports = await db.query<{ reason: string; state: string; created_at: Date }>(
      'SELECT reason, state, created_at FROM reports WHERE reporter = $1 ORDER BY created_at',
      [me],
    );
    const signIns = await db.query<{ created_at: Date; revoked_at: Date | null }>(
      'SELECT created_at, revoked_at FROM session_families WHERE account_id = $1 ORDER BY created_at',
      [me],
    );
    const events = await db.query<{ kind: string; created_at: Date }>(
      'SELECT kind, created_at FROM audit_events WHERE account_id = $1 ORDER BY created_at',
      [me],
    );
    // Calls you were in (never their content), push settings, and the devices
    // registered for push (platform and dates only; tokens are not yours to keep).
    const callRows = await db.query<{
      kind: string;
      role: string;
      state: string;
      with_name: string | null;
      created_at: Date;
      answered_at: Date | null;
      ended_at: Date | null;
    }>(
      `SELECT c.kind, CASE WHEN c.caller = $1 THEN 'caller' ELSE 'callee' END AS role, c.state,
              p.display_name AS with_name, c.created_at, c.answered_at, c.ended_at
       FROM calls c
       LEFT JOIN profiles p ON p.account_id = CASE WHEN c.caller = $1 THEN c.callee ELSE c.caller END
       WHERE c.caller = $1 OR c.callee = $1
       ORDER BY c.created_at`,
      [me],
    );
    const [prefs] = await db.query<Record<string, boolean>>(
      'SELECT matches, messages, likes, calls FROM notification_prefs WHERE account_id = $1',
      [me],
    );
    const deviceRows = await db.query<{ platform: string; created_at: Date; last_seen_at: Date }>(
      'SELECT platform, created_at, last_seen_at FROM devices WHERE account_id = $1 ORDER BY created_at',
      [me],
    );
    const now = clock.now();
    await audit(db, me, 'data_exported', now);
    reply.header('cache-control', 'no-store');
    return {
      format: 'vawra-export-1',
      generated_at: now.toISOString(),
      account: {
        email: acct ? sealer.open(acct.email_sealed) : null,
        created_at: iso(acct?.created_at ?? null),
        age_state: acct?.age_state,
        lifecycle: acct?.lifecycle,
        deletion_effective_at: iso(acct?.deletion_effective_at ?? null),
        share_read_receipts: acct?.share_read_receipts,
      },
      profile: profile
        ? { ...profile, updated_at: iso(profile.updated_at as Date) }
        : null,
      suspension: suspension?.suspended_at
        ? { since: iso(suspension.suspended_at), reason: suspension.suspension_reason }
        : null,
      appeals_you_made: appeals.map((a) => ({
        message: a.message,
        state: a.state,
        at: iso(a.created_at),
        decided_at: iso(a.decided_at),
      })),
      approximate_area: cell
        ? { ...cell, cell_km: cellKm, updated_at: iso(area!.location_updated_at) }
        : null,
      photos: photoRows.map((p) => ({
        state: p.state,
        uploaded_at: iso(p.created_at),
        decided_at: iso(p.decided_at),
      })),
      calls: callRows.map((c) => ({
        kind: c.kind,
        you_were: c.role,
        with: c.with_name,
        outcome: c.state,
        at: iso(c.created_at),
        answered_at: iso(c.answered_at),
        ended_at: iso(c.ended_at),
      })),
      notifications: prefs ?? { matches: true, messages: true, likes: true, calls: true },
      push_devices: deviceRows.map((d) => ({
        platform: d.platform,
        registered_at: iso(d.created_at),
        last_seen_at: iso(d.last_seen_at),
      })),
      swipes: swipes.map((s) => ({ kind: s.kind, at: iso(s.created_at) })),
      matches: matches.map((m) => ({
        with: m.peer_name,
        status: m.status,
        matched_at: iso(m.created_at),
        messages_you_sent: sent
          .filter((x) => x.match_id === m.id)
          .map((x) => ({ at: iso(x.created_at), text: x.body })),
      })),
      blocks: blocks.map((b) => ({ at: iso(b.created_at) })),
      reports_you_made: reports.map((r) => ({ reason: r.reason, state: r.state, at: iso(r.created_at) })),
      sign_ins: signIns.map((s) => ({ signed_in_at: iso(s.created_at), ended_at: iso(s.revoked_at) })),
      security_events: events.map((e) => ({ kind: e.kind, at: iso(e.created_at) })),
      not_included: [
        'Messages other people sent you, their profiles and their account IDs',
        'Internal safety and moderation notes, and which moderator decided',
        'Anything kept only on your phone',
      ],
    };
  });

  app.post('/v1/me/deletion', async (request, reply) => {
    const account = requireAccount(request);
    await requireRecentSignIn(services, account);
    const now = clock.now();
    const effective = await db.transaction(async (tx) => {
      const [row] = await tx.query<{ lifecycle: string; deletion_effective_at: Date | null }>(
        'SELECT lifecycle, deletion_effective_at FROM accounts WHERE id = $1 FOR UPDATE',
        [account.id],
      );
      // Asking twice keeps the first date.
      if (row?.lifecycle === 'deletion_scheduled' && row.deletion_effective_at) {
        return new Date(row.deletion_effective_at);
      }
      const at = new Date(now.getTime() + services.deletionGraceSeconds * 1000);
      await tx.query(
        `UPDATE accounts SET lifecycle_before_deletion = lifecycle,
                lifecycle = 'deletion_scheduled', deletion_effective_at = $2
         WHERE id = $1`,
        [account.id, at],
      );
      // Signed out everywhere, this device included.
      await tx.query(
        'UPDATE session_families SET revoked_at = $2 WHERE account_id = $1 AND revoked_at IS NULL',
        [account.id, now],
      );
      await audit(tx, account.id, 'deletion_scheduled', now);
      return at;
    });
    await endCalls(db, services.nudges, services.signals, { accountId: account.id }, 'leaving', now);
    return reply.code(202).send({ state: 'scheduled', effective_at: effective.toISOString() });
  });

  app.delete('/v1/me/deletion', async (request, reply) => {
    const account = requireAccount(request);
    await requireRecentSignIn(services, account);
    const now = clock.now();
    const [row] = await db.query<{ deletion_effective_at: Date | null }>(
      "SELECT deletion_effective_at FROM accounts WHERE id = $1 AND lifecycle = 'deletion_scheduled'",
      [account.id],
    );
    if (!row?.deletion_effective_at) return fail(409, 'no_deletion_scheduled');
    if (new Date(row.deletion_effective_at) <= now) return fail(410, 'deletion_effective');
    await db.query(
      `UPDATE accounts SET lifecycle = COALESCE(lifecycle_before_deletion, 'active'),
              lifecycle_before_deletion = NULL, deletion_effective_at = NULL
       WHERE id = $1 AND lifecycle = 'deletion_scheduled'`,
      [account.id],
    );
    await audit(db, account.id, 'deletion_cancelled', now);
    return noContent(reply);
  });
}
