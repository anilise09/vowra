import type { Db } from './db.js';
import { MemoryNudgeBus, type Nudge, type NudgeBus } from './nudges.js';

/**
 * State that more than one server must share, through the PostgreSQL they
 * already use: live-update nudges (LISTEN/NOTIFY) and who has the app open
 * (a small table). With one server everything stays in memory instead.
 */

const channel = 'vawra_nudges';

/**
 * Nudges for people connected to any server. A nudge is delivered here at
 * once and sent to the other servers through NOTIFY; each ignores its own.
 * Nudges carry no private content (an account id, a kind, a match or call id),
 * so nothing private travels through the database's notification channel.
 */
export class PgNudgeBus implements NudgeBus {
  private readonly local = new MemoryNudgeBus();
  private stop?: () => Promise<void>;

  constructor(
    private readonly db: Db,
    private readonly instanceId: string,
    private readonly log: (message: string) => void = () => {},
  ) {}

  async start(): Promise<void> {
    if (!this.db.listen) throw new Error('this database cannot listen for notifications');
    this.stop = await this.db.listen(channel, (payload) => {
      try {
        const message = JSON.parse(payload) as { i: string; a: string; n: Nudge };
        if (message.i !== this.instanceId) this.local.publish(message.a, message.n);
      } catch {
        this.log('ignored a malformed nudge notification');
      }
    });
  }

  async close(): Promise<void> {
    await this.stop?.();
  }

  publish(accountId: string, nudge: Nudge): void {
    this.local.publish(accountId, nudge);
    const payload = JSON.stringify({ i: this.instanceId, a: accountId, n: nudge });
    this.db.query('SELECT pg_notify($1, $2)', [channel, payload]).catch(() => this.log('a nudge was not shared'));
  }

  subscribe(accountId: string, listener: (nudge: Nudge) => void): () => void {
    return this.local.subscribe(accountId, listener);
  }

  /** Streams on this server only; the shared answer is [Presence]. */
  listeners(accountId: string): number {
    return this.local.listeners(accountId);
  }
}

/** Whether someone has the app open with a live connection, on any server. */
export interface Presence {
  connected(accountId: string): Promise<boolean>;
  /** Records an open stream; the handle keeps it fresh and ends it. */
  track(accountId: string): Promise<{ beat(): Promise<void>; end(): Promise<void> }>;
}

/** One server: its own open streams are the whole truth. */
export class LocalPresence implements Presence {
  constructor(private readonly nudges: NudgeBus) {}
  async connected(accountId: string) {
    return this.nudges.listeners(accountId) > 0;
  }
  async track() {
    return { beat: async () => {}, end: async () => {} };
  }
}

/** A stream not heard from for this long is gone (its server stopped without saying). */
export const presenceStaleSeconds = 70;

/** Several servers: each open stream is a row, refreshed with the 25-second heartbeat. */
export class DbPresence implements Presence {
  constructor(
    private readonly db: Db,
    private readonly instanceId: string,
  ) {}

  async connected(accountId: string) {
    const rows = await this.db.query(
      `SELECT 1 FROM stream_presence WHERE account_id = $1
       AND seen_at > now() - make_interval(secs => $2) LIMIT 1`,
      [accountId, presenceStaleSeconds],
    );
    return rows.length > 0;
  }

  async track(accountId: string) {
    const id = crypto.randomUUID();
    await this.db.query(
      'INSERT INTO stream_presence (stream_id, account_id, instance_id, seen_at) VALUES ($1, $2, $3, now())',
      [id, accountId, this.instanceId],
    );
    return {
      beat: async () => {
        await this.db.query('UPDATE stream_presence SET seen_at = now() WHERE stream_id = $1', [id]);
      },
      end: async () => {
        await this.db.query('DELETE FROM stream_presence WHERE stream_id = $1', [id]);
      },
    };
  }
}
