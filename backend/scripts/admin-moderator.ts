// Operator command, run on the server host, never an HTTP endpoint. Works on
// the production database (DATABASE_URL) and the local development one.
//   npm run admin:moderator -- grant <email> --confirm
//   npm run admin:moderator -- revoke <email> --confirm
//   npm run admin:moderator -- reset-2fa <email> --confirm   (a lost authenticator)
// Every change is an audit event. A moderator must then set up an
// authenticator in the app before any moderation action.
import { audit } from '../src/context.js';
import { loadConfig } from '../src/config.js';
import { Sealer } from '../src/crypto.js';
import { migrate, openPglite, openPostgres } from '../src/db.js';

const [action, rawEmail] = process.argv.slice(2);
const email = rawEmail?.trim().toLowerCase();
if (!['grant', 'revoke', 'reset-2fa'].includes(action ?? '') || !email || email.startsWith('--')) {
  console.error('usage: npm run admin:moderator -- grant|revoke|reset-2fa <email> --confirm');
  process.exit(1);
}
if (!process.argv.includes('--confirm')) {
  console.error(`Nothing changed. Add --confirm to ${action} moderation for ${email}.`);
  process.exit(1);
}
const config = loadConfig();
const db = config.databaseUrl ? await openPostgres(config.databaseUrl) : await openPglite(config.dataDir);
await migrate(db);
const sealer = new Sealer(config.dataKey, config.lookupKey);
const [account] = await db.query<{ id: string; role: string }>('SELECT id, role FROM accounts WHERE email_lookup = $1', [
  sealer.lookup(email),
]);
if (!account) {
  console.error('No account with that email. The person signs in to the app once first.');
  await db.close();
  process.exit(1);
}
const now = new Date();
await db.transaction(async (tx) => {
  if (action === 'grant') {
    await tx.query("UPDATE accounts SET role = 'moderator' WHERE id = $1", [account.id]);
    await audit(tx, account.id, 'admin_moderator_granted', now);
  } else if (action === 'revoke') {
    await tx.query("UPDATE accounts SET role = 'member' WHERE id = $1", [account.id]);
    await tx.query('DELETE FROM moderator_second_factor WHERE account_id = $1', [account.id]);
    await tx.query('UPDATE session_families SET mod_verified_until = NULL WHERE account_id = $1', [account.id]);
    await audit(tx, account.id, 'admin_moderator_revoked', now);
  } else {
    // A lost phone: the old authenticator stops working and every sign-in must verify again.
    await tx.query('DELETE FROM moderator_second_factor WHERE account_id = $1', [account.id]);
    await tx.query('UPDATE session_families SET mod_verified_until = NULL WHERE account_id = $1', [account.id]);
    await audit(tx, account.id, 'admin_moderator_2fa_reset', now);
  }
});
console.log(
  action === 'grant'
    ? 'Moderator granted. They set up an authenticator in the app before moderating.'
    : action === 'revoke'
      ? 'Moderation removed, with their authenticator.'
      : 'Authenticator reset. They set up a new one in the app.',
);
await db.close();
