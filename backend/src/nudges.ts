/**
 * A nudge says only that something changed for an account; the app then
 * fetches through the normal authenticated routes. It never carries message
 * text, names or photos, so nothing private travels through the push path.
 */
export interface Nudge {
  kind: 'message' | 'match' | 'like' | 'read' | 'typing' | 'call';
  match_id?: string;
  /** For 'call': which call changed; the app fetches its state and setup messages. */
  call_id?: string;
}

export interface NudgeBus {
  publish(accountId: string, nudge: Nudge): void;
  /** Returns the unsubscribe function. */
  subscribe(accountId: string, listener: (nudge: Nudge) => void): () => void;
  listeners(accountId: string): number;
}

/**
 * Single-process bus. With more than one server instance this is replaced by
 * a shared broker behind the same interface.
 */
export class MemoryNudgeBus implements NudgeBus {
  private readonly byAccount = new Map<string, Set<(nudge: Nudge) => void>>();

  publish(accountId: string, nudge: Nudge): void {
    for (const listener of this.byAccount.get(accountId) ?? []) {
      try {
        listener(nudge);
      } catch {
        // One broken stream never stops the others.
      }
    }
  }

  subscribe(accountId: string, listener: (nudge: Nudge) => void): () => void {
    const set = this.byAccount.get(accountId) ?? new Set();
    set.add(listener);
    this.byAccount.set(accountId, set);
    return () => {
      set.delete(listener);
      if (set.size === 0) this.byAccount.delete(accountId);
    };
  }

  listeners(accountId: string): number {
    return this.byAccount.get(accountId)?.size ?? 0;
  }
}
