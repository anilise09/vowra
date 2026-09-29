// Restores a development backup. The current database and photos are moved
// aside (never deleted), then the backup is loaded and checked.
//   npm run dev:restore -- <backup name>     (npm run dev:restore lists them)
import { cpSync, existsSync, renameSync } from 'node:fs';
import { listBackups, readBackup } from '../src/backup.js';
import { loadConfig } from '../src/config.js';
import { migrate, openPglite } from '../src/db.js';

const config = loadConfig();
if (config.databaseUrl) {
  console.error('Refusing: this restores the local PGlite database only.');
  process.exit(1);
}
const name = process.argv[2];
if (!name) {
  console.log(listBackups('.data/backups').join('\n') || 'No backups yet.');
  process.exit(0);
}
if (!listBackups('.data/backups').includes(name)) {
  console.error('No backup with that name.');
  process.exit(1);
}
const started = Date.now();
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const dataDir = config.dataDir ?? '.data/pglite';
if (existsSync(dataDir)) renameSync(dataDir, `${dataDir}.before-restore-${stamp}`);
if (existsSync(config.mediaDir)) renameSync(config.mediaDir, `${config.mediaDir}.before-restore-${stamp}`);
const backup = readBackup('.data/backups', name);
const db = await openPglite(dataDir, backup.db);
await migrate(db);
const [row] = await db.query<{ n: number }>('SELECT count(*)::int AS n FROM accounts');
await db.close();
if (existsSync(backup.mediaDir)) cpSync(backup.mediaDir, config.mediaDir, { recursive: true });
console.log(`Restored ${name}: ${row?.n ?? 0} accounts, in ${Date.now() - started} ms.`);
