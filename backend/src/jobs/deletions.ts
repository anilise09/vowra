import { audit, type Clock } from '../context.js';
import type { Db } from '../db.js';
import type { MediaStore } from '../media.js';

/**
 * Removes every account whose scheduled deletion time has passed. Deleting the
 * account row cascades to its profile, sessions, swipes, matches (with both
 * people's messages, so no conversation copy can rebuild it), blocks and
 * reports. Audit rows lose the account id; sign-in requests for the email go.
 */
export async function runDueDeletions(db: Db, clock: Clock, media?: MediaStore): Promise<number> {
  const now = clock.now();
  const due = await db.query<{ id: string; email_lookup: string }>(
    `SELECT id, email_lookup FROM accounts
     WHERE lifecycle = 'deletion_scheduled' AND deletion_effective_at <= $1`,
    [now],
  );
  for (const account of due) {
    // Photo files first: the rows go with the account.
    const photos = await db.query<{ id: string }>('SELECT id FROM media WHERE owner = $1', [account.id]);
    for (const photo of photos) await media?.delete(photo.id);
    await db.transaction(async (tx) => {
      await tx.query('UPDATE audit_events SET account_id = NULL WHERE account_id = $1', [
        account.id,
      ]);
      await tx.query('DELETE FROM auth_requests WHERE email_lookup = $1', [account.email_lookup]);
      await tx.query(
        `DELETE FROM accounts WHERE id = $1 AND lifecycle = 'deletion_scheduled'
           AND deletion_effective_at <= $2`,
        [account.id, now],
      );
      await audit(tx, null, 'account_deleted', now);
    });
  }
  return due.length;
}
