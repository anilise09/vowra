// Development backup of the local PGlite database and photo files, keeping the
// newest seven. Stop the server first: PGlite allows one process.
//   npm run dev:backup
// Production uses the database host's backups; see docs/RECOVERY.md.
import { backupTo } from '../src/backup.js';
import { loadConfig } from '../src/config.js';
import { openPglite } from '../src/db.js';

const config = loadConfig();
if (config.databaseUrl) {
  console.error('Refusing: this backs up the local PGlite database only.');
  process.exit(1);
}
const started = Date.now();
const db = await openPglite(config.dataDir);
const name = await backupTo('.data/backups', db, config.mediaDir, new Date());
await db.close();
console.log(`Backup ${name} written in ${Date.now() - started} ms.`);
