import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { callRules, endCalls, iceFor, liveCall } from '../calls.js';
import { audit, fail, noContent, requireDatingAccess, type Services } from '../context.js';
import { openConversation } from './chat.js';

const uuid = z.string().uuid();
const startBody = z.object({ kind: z.enum(['video', 'audio']) }).strict();
const readyBody = z.object({ ready: z.boolean() }).strict();
const signalBody = z
  .object({ type: z.enum(['offer', 'answer', 'candidate']), data: z.string().max(callRules.signalBytes) })
  .strict();

interface CallRow {
  id: string;
  match_id: string;
  caller: string;
  callee: string;
  kind: string;
  state: string;
  created_at: Date;
  answered_at: Date | null;
  ended_at: Date | null;
  end_reason: string | null;
}

export function callRoutes(app: FastifyInstance, services: Services) {
  const { db, clock, nudges } = services;
  const signals = services.signals;

  /** A call you are part of, with a ring that ran out marked missed. */
  async function myCall(me: string, rawId: string): Promise<CallRow> {
    const id = uuid.safeParse(rawId);
    if (!id.success) return fail(404, 'not_found');
    const now = clock.now();
    await db.query(
      `UPDATE calls SET state = 'missed', ended_at = $2, end_reason = 'no_answer'
       WHERE id = $1 AND state = 'ringing' AND created_at < $3`,
      [id.data, now, new Date(now.getTime() - callRules.ringSeconds * 1000)],
    );
    const [row] = await db.query<CallRow>('SELECT * FROM calls WHERE id = $1 AND (caller = $2 OR callee = $2)', [
      id.data,
      me,
    ]);
    if (!row) return fail(404, 'not_found');
    if (row.state !== 'ringing' && row.state !== 'active') {
      signals.clear(row.id);
      return row;
    }
    // A block, unmatch, suspension or deletion ends the call at the next step
    // even if the event that should have ended it was missed.
    try {
      await openConversation(db, me, row.match_id);
    } catch {
      await endCalls(db, nudges, signals, { matchId: row.match_id }, 'closed', now);
      const [ended] = await db.query<CallRow>('SELECT * FROM calls WHERE id = $1', [row.id]);
      return ended!;
    }
    return row;
  }

  const view = (row: CallRow, me: string, now: Date) => ({
    call_id: row.id,
    match_id: row.match_id,
    kind: row.kind,
    state: row.state,
    role: row.caller === me ? 'caller' : 'callee',
    started_at: new Date(row.created_at).toISOString(),
    ...(row.state === 'ringing' || row.state === 'active'
      ? { ice: services.callConfig ? iceFor(services.callConfig, me, now) : null }
      : {}),
  });

  app.put('/v1/matches/:matchId/call-ready', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const body = readyBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    const match = await openConversation(db, me.id, (request.params as { matchId: string }).matchId);
    if (body.data!.ready) {
      await db.query(
        `INSERT INTO call_readiness (match_id, account_id, created_at) VALUES ($1, $2, $3)
         ON CONFLICT DO NOTHING`,
        [match.id, me.id, clock.now()],
      );
    } else {
      await db.query('DELETE FROM call_readiness WHERE match_id = $1 AND account_id = $2', [match.id, me.id]);
      await endCalls(db, nudges, signals, { matchId: match.id }, 'not_ready', clock.now());
    }
    nudges.publish(match.peer, { kind: 'match', match_id: match.id });
    return noContent(reply);
  });

  app.post('/v1/matches/:matchId/calls', async (request) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const body = startBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    if (!services.callConfig) fail(503, 'calls_unavailable');
    const match = await openConversation(db, me.id, (request.params as { matchId: string }).matchId);
    const now = clock.now();
    const ready = await db.query('SELECT account_id FROM call_readiness WHERE match_id = $1', [match.id]);
    if (ready.length < 2) fail(409, 'not_ready');
    // One transaction holding both people, so two calls can never start at once.
    const row = await db.transaction(async (tx) => {
      await tx.query('SELECT id FROM accounts WHERE id IN ($1, $2) ORDER BY id FOR UPDATE', [me.id, match.peer]);
      // Old rings expire first so a missed call never blocks a new one.
      await tx.query(
        `UPDATE calls SET state = 'missed', ended_at = $1, end_reason = 'no_answer'
         WHERE state = 'ringing' AND created_at < $2`,
        [now, new Date(now.getTime() - callRules.ringSeconds * 1000)],
      );
      const busy = await tx.query(
        `SELECT 1 FROM calls WHERE ${liveCall} AND (caller IN ($1, $2) OR callee IN ($1, $2))`,
        [me.id, match.peer],
      );
      if (busy.length > 0) fail(409, 'busy');
      const [recent] = await tx.query<{ n: number }>(
        'SELECT count(*)::int AS n FROM calls WHERE caller = $1 AND created_at > $2',
        [me.id, new Date(now.getTime() - 60 * 60 * 1000)],
      );
      if ((recent?.n ?? 0) >= callRules.callsPerHour) fail(429, 'call_limit');
      const [inserted] = await tx.query<CallRow>(
        `INSERT INTO calls (id, match_id, caller, callee, kind, state, created_at)
         VALUES ($1, $2, $3, $4, $5, 'ringing', $6) RETURNING *`,
        [crypto.randomUUID(), match.id, me.id, match.peer, body.data!.kind, now],
      );
      return inserted!;
    });
    await audit(db, me.id, 'call_started', now);
    nudges.publish(match.peer, { kind: 'call', call_id: row.id, match_id: match.id });
    services.notifier.notify(match.peer, 'call', { call_id: row.id, match_id: match.id });
    return view(row, me.id, now);
  });

  app.get('/v1/calls/:callId', async (request) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const row = await myCall(me.id, (request.params as { callId: string }).callId);
    return view(row, me.id, clock.now());
  });

  /** The callee answers; myCall has just checked the conversation is still open. */
  app.post('/v1/calls/:callId/answer', async (request) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const row = await myCall(me.id, (request.params as { callId: string }).callId);
    if (row.callee !== me.id || row.state !== 'ringing') fail(409, 'not_ringing');
    const now = clock.now();
    const answered = await db.query(
      "UPDATE calls SET state = 'active', answered_at = $2 WHERE id = $1 AND state = 'ringing' RETURNING id",
      [row.id, now],
    );
    if (answered.length === 0) fail(409, 'not_ringing');
    nudges.publish(row.caller, { kind: 'call', call_id: row.id });
    return view({ ...row, state: 'active' }, me.id, now);
  });

  app.post('/v1/calls/:callId/decline', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const row = await myCall(me.id, (request.params as { callId: string }).callId);
    if (row.callee !== me.id || row.state !== 'ringing') fail(409, 'not_ringing');
    await db.query(
      "UPDATE calls SET state = 'declined', ended_at = $2, end_reason = 'declined' WHERE id = $1",
      [row.id, clock.now()],
    );
    signals.clear(row.id);
    nudges.publish(row.caller, { kind: 'call', call_id: row.id });
    return noContent(reply);
  });

  /** Either person hangs up; before an answer the caller cancels. */
  app.post('/v1/calls/:callId/end', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const row = await myCall(me.id, (request.params as { callId: string }).callId);
    if (row.state === 'ringing' || row.state === 'active') {
      const now = clock.now();
      await db.query(
        `UPDATE calls SET state = CASE WHEN state = 'ringing' THEN 'cancelled' ELSE 'ended' END,
                ended_at = $2, end_reason = 'hung_up' WHERE id = $1`,
        [row.id, now],
      );
      signals.clear(row.id);
      nudges.publish(row.caller === me.id ? row.callee : row.caller, { kind: 'call', call_id: row.id });
    }
    return noContent(reply);
  });

  /** Setup messages between the two phones, held in memory only. */
  app.post('/v1/calls/:callId/signals', async (request, reply) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const row = await myCall(me.id, (request.params as { callId: string }).callId);
    const body = signalBody.safeParse(request.body);
    if (!body.success) fail(400, 'invalid_request');
    if (row.state !== 'ringing' && row.state !== 'active') fail(409, 'call_over');
    if (signals.countFrom(row.id, me.id) >= callRules.signalsPerCall) fail(429, 'slow_down');
    signals.push(row.id, me.id, body.data!.type, body.data!.data);
    nudges.publish(row.caller === me.id ? row.callee : row.caller, { kind: 'call', call_id: row.id });
    return reply.code(202).send({ ok: true });
  });

  app.get('/v1/calls/:callId/signals', async (request) => {
    const me = requireDatingAccess(request, { allowPaused: true });
    const row = await myCall(me.id, (request.params as { callId: string }).callId);
    const after = Number((request.query as { after?: string }).after ?? 0) || 0;
    return {
      state: row.state,
      signals: signals.for(row.id, me.id, after).map(({ seq, type, data }) => ({ seq, type, data })),
    };
  });
}
