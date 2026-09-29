// Development only: makes a local test account a moderator (or a member again
// with --remove), because there is no staff console or staff sign-in yet. A
// command on the developer's machine, never an HTTP endpoint; refuses a real
// database. Stop the server first: PGlite allows one process.
//   npm run dev:moderator -- <email> [--remove]
import { loadConfig } from '../src/config.js';
import { Sealer } from '../src/crypto.js';
import { migrate, openPglite } from '../src/db.js';

const email = process.argv[2]?.trim().toLowerCase();
if (!email || email.startsWith('--')) {
  console.error('usage: npm run dev:moderator -- <email> [--remove]');
  process.exit(1);
}
const config = loadConfig();
if (config.databaseUrl) {
  console.error('Refusing: dev:moderator only works on the local PGlite development database.');
  process.exit(1);
}
const db = await openPglite(config.dataDir);
await migrate(db);
const sealer = new Sealer(config.dataKey, config.lookupKey);
const role = process.argv.includes('--remove') ? 'member' : 'moderator';
const rows = await db.query<{ id: string }>(
  'UPDATE accounts SET role = $2 WHERE email_lookup = $1 RETURNING id',
  [sealer.lookup(email), role],
);
console.log(rows.length ? `Role set to ${role} for local development.` : 'No local account with that email.');
await db.close();
