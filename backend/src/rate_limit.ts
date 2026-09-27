import type { Clock } from './context.js';

/** Fixed-window counter. In-memory: one process only, which is all this build runs. */
export class RateLimiter {
  private readonly windows = new Map<string, { start: number; count: number }>();

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
    private readonly clock: Clock,
  ) {}

  /** Returns true and counts the hit when under the limit. */
  take(key: string): boolean {
    const now = this.clock.now().getTime();
    const window = this.windows.get(key);
    if (!window || now - window.start >= this.windowMs) {
      this.windows.set(key, { start: now, count: 1 });
      return true;
    }
    if (window.count >= this.limit) return false;
    window.count += 1;
    return true;
  }
}
