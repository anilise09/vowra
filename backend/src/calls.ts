import { createHmac } from 'node:crypto';
import type { Db } from './db.js';
import type { NudgeBus } from './nudges.js';

/**
 * Voice and video calls between two matched people who have both said they
 * are open to a call. Vawra carries only the setup messages between the two
 * phones, in memory, for the life of the call; the call itself goes phone to
 * phone (through a TURN relay in production). Nothing is recorded: the server
 * keeps who called, the kind, the times and how it ended.
 */
export const callRules = {
  ringSeconds: 45,
  callsPerHour: 10,
  signalsPerCall: 400,
  signalBytes: 20_000,
};

export interface CallConfig {
  /** 'relay' hides both people's addresses from each other (production). */
  policy: 'relay' | 'all';
  stun: string[];
  turn?: { urls: string[]; secret: Buffer };
}

/**
 * From the environment: TURN (VAWRA_TURN_URLS, VAWRA_TURN_SECRET) means
 * relay-only calls. Without TURN, calls stay off unless VAWRA_CALLS_DEV_P2P=1,
 * a development switch for direct calls, which show each phone's address to
 * the other.
 */
export function callConfigFrom(env: NodeJS.ProcessEnv): CallConfig | null {
  const urls = env.VAWRA_TURN_URLS?.split(',').map((u) => u.trim()).filter(Boolean);
  if (urls?.length && env.VAWRA_TURN_SECRET) {
    return { policy: 'relay', stun: [], turn: { urls, secret: Buffer.from(env.VAWRA_TURN_SECRET) } };
  }
  if (env.VAWRA_CALLS_DEV_P2P === '1') {
    const stun = env.VAWRA_STUN_URLS ?? 'stun:stun.l.google.com:19302';
    return { policy: 'all', stun: stun.split(',').map((u) => u.trim()).filter(Boolean) };
  }
  return null;
}

/** ICE servers for one participant; TURN credentials last the call's length. */
export function iceFor(config: CallConfig, accountId: string, now: Date) {
  const servers: { urls: string[]; username?: string; credential?: string }[] = [];
  if (config.stun.length) servers.push({ urls: config.stun });
  if (config.turn) {
    const username = `${Math.floor(now.getTime() / 1000) + 2 * 60 * 60}:${accountId}`;
    const credential = createHmac('sha1', config.turn.secret).update(username).digest('base64');
    servers.push({ urls: config.turn.urls, username, credential });
  }
  return { policy: config.policy, servers };
}

type Signal = { seq: number; from: string; type: string; data: string };

/** Setup messages, in memory only, removed when the call ends. */
export class SignalBox {
  private readonly byCall = new Map<string, Signal[]>();
  private seq = 0;

  push(callId: string, from: string, type: string, data: string) {
    const list = this.byCall.get(callId) ?? [];
    list.push({ seq: ++this.seq, from, type, data });
    this.byCall.set(callId, list);
  }

  countFrom(callId: string, from: string) {
    return (this.byCall.get(callId) ?? []).filter((s) => s.from === from).length;
  }

  for(callId: string, reader: string, after: number) {
    return (this.byCall.get(callId) ?? []).filter((s) => s.from !== reader && s.seq > after);
  }

  clear(callId: string) {
    this.byCall.delete(callId);
  }
}

export const liveCall = "state IN ('ringing','active')";

/** Which live calls to end: one person's, one match's, or one pair's. */
export type CallScope = { accountId: string } | { matchId: string } | { pair: [string, string] };

/**
 * Ends every live call in scope: used by block, unmatch, suspension and
 * deletion so a call never outlives the right to it. Both phones get a nudge
 * and see only that the call ended, never why.
 */
export async function endCalls(
  db: Db,
  nudges: NudgeBus,
  signals: SignalBox,
  scope: CallScope,
  reason: string,
  now: Date,
) {
  const [where, params] =
    'accountId' in scope
      ? ['(caller = $3 OR callee = $3)', [scope.accountId]]
      : 'matchId' in scope
        ? ['match_id = $3', [scope.matchId]]
        : ['((caller = $3 AND callee = $4) OR (caller = $4 AND callee = $3))', scope.pair];
  const rows = await db.query<{ id: string; caller: string; callee: string }>(
    `UPDATE calls SET state = CASE WHEN state = 'ringing' THEN 'cancelled' ELSE 'ended' END,
            ended_at = $1, end_reason = $2
     WHERE ${liveCall} AND ${where}
     RETURNING id, caller, callee`,
    [now, reason, ...params],
  );
  for (const row of rows) {
    signals.clear(row.id);
    nudges.publish(row.caller, { kind: 'call', call_id: row.id });
    nudges.publish(row.callee, { kind: 'call', call_id: row.id });
  }
  return rows.length;
}
