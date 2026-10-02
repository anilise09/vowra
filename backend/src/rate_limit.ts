import type { Clock } from './context.js';
import type { Db } from './db.js';

/** Atomic fixed-window counter shared by every server using the same database. */
export class DbRateLimiter {
  constructor(
    private readonly db: Db,
    private readonly limit: number,
    private readonly windowMs: number,
    private readonly clock: Clock,
  ) {}

  /** The caller must pass an HMAC lookup, never a raw identifier or IP address. */
  async take(keyHash: string): Promise<boolean> {
    const now = this.clock.now();
    const expiredBefore = new Date(now.getTime() - this.windowMs);
    const rows = await this.db.query(
      `INSERT INTO auth_rate_limit_windows (key_hash, window_start, hits)
       VALUES ($1, $2, 1)
       ON CONFLICT (key_hash) DO UPDATE SET
         window_start = CASE WHEN auth_rate_limit_windows.window_start <= $3
                             THEN $2 ELSE auth_rate_limit_windows.window_start END,
         hits = CASE WHEN auth_rate_limit_windows.window_start <= $3
                     THEN 1 ELSE auth_rate_limit_windows.hits + 1 END
       WHERE auth_rate_limit_windows.window_start <= $3
          OR auth_rate_limit_windows.hits < $4
       RETURNING hits`,
      [keyHash, now, expiredBefore, this.limit],
    );
    return rows.length === 1;
  }

  /** Whether the current window is used up, without counting anything. */
  async exhausted(keyHash: string): Promise<boolean> {
    const now = this.clock.now();
    const [row] = await this.db.query<{ hits: number }>(
      'SELECT hits FROM auth_rate_limit_windows WHERE key_hash = $1 AND window_start > $2',
      [keyHash, new Date(now.getTime() - this.windowMs)],
    );
    return (row?.hits ?? 0) >= this.limit;
  }
}
