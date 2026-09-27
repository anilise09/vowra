// Development only: marks a local test account as having passed age assurance,
// because no age-assurance provider has been reviewed yet. This is a command on
// the developer's machine, never an HTTP endpoint, and it refuses a real database.
import { loadConfig } from '../src/config.js';
import { Sealer } from '../src/crypto.js';
import { openPglite } from '../src/db.js';

const [email, ageArg] = process.argv.slice(2);
if (!email || !ageArg) {
  console.error('usage: npm run dev:assure -- <email> <age>');
  process.exit(1);
}
const config = loadConfig();
if (config.databaseUrl) {
  console.error('Refusing: dev:assure only works on the local PGlite development database.');
  process.exit(1);
}
const age = Number(ageArg);
if (!Number.isInteger(age) || age < 18 || age > 99) {
  console.error('Age must be a whole number from 18 to 99.');
  process.exit(1);
}
const db = await openPglite(config.dataDir);
const sealer = new Sealer(config.dataKey, config.lookupKey);
const [account] = await db.query<{ id: string }>(
  "UPDATE accounts SET age_state = 'adult_verified' WHERE email_lookup = $1 RETURNING id",
  [sealer.lookup(email.trim().toLowerCase())],
);
if (!account) {
  console.error('No local account with that email. Sign in once first.');
} else {
  await db.query('UPDATE profiles SET public_age = $2 WHERE account_id = $1', [account.id, age]);
  console.log('Marked as adult_verified for local development.');
}
await db.close();
