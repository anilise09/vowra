// Development only: loads the app's 260 synthetic sample profiles into the
// local PGlite test database as age-verified demo members with their bundled
// portraits, so the server build has a full deck to test with.
//   npm run dev:seed-demo            add (idempotent)
//   npm run dev:seed-demo -- --remove  remove them all
// Stop the server first: PGlite allows one process. Refuses a real database.
import { readFileSync } from 'node:fs';
import { loadConfig } from '../src/config.js';
import { Sealer } from '../src/crypto.js';
import { migrate, openPglite } from '../src/db.js';
import { removeDemo, seedDemo, type DemoProfile } from '../src/demo_seed.js';

const config = loadConfig();
if (config.databaseUrl) {
  console.error('Refusing: demo members only go into the local PGlite development database.');
  process.exit(1);
}
const db = await openPglite(config.dataDir);
await migrate(db);
if (process.argv.includes('--remove')) {
  console.log(`Removed ${await removeDemo(db)} demo members.`);
} else {
  const people = JSON.parse(
    readFileSync(new URL('../fixtures/demo_profiles.json', import.meta.url), 'utf8'),
  ) as DemoProfile[];
  const sealer = new Sealer(config.dataKey, config.lookupKey);
  const added = await seedDemo(db, sealer, people, new Date());
  console.log(`Added ${added} demo members (${people.length - added} were already there).`);
}
await db.close();
