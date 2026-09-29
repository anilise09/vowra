import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Db } from './db.js';

/** Daily backups kept; older ones are removed, so deleted accounts leave backups too. */
export const backupsKept = 7;

/**
 * A backup is the database snapshot plus the photo files, in one folder
 * named by time. Emails in it stay sealed: the keys are never in a backup.
 */
export async function backupTo(root: string, db: Db, mediaDir: string, now: Date): Promise<string> {
  if (!db.dump) throw new Error('This database cannot be dumped here; use the host\'s backups.');
  const name = now.toISOString().replace(/[:.]/g, '-');
  const dir = join(root, name);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'db.tar.gz'), await db.dump());
  if (existsSync(mediaDir)) cpSync(mediaDir, join(dir, 'media'), { recursive: true });
  pruneBackups(root, backupsKept);
  return name;
}

export function listBackups(root: string): string[] {
  if (!existsSync(root)) return [];
  return readdirSync(root)
    .filter((n) => existsSync(join(root, n, 'db.tar.gz')))
    .sort();
}

export function pruneBackups(root: string, keep: number) {
  const all = listBackups(root);
  for (const old of all.slice(0, Math.max(0, all.length - keep))) {
    rmSync(join(root, old), { recursive: true, force: true });
  }
}

export function readBackup(root: string, name: string) {
  return {
    db: readFileSync(join(root, name, 'db.tar.gz')),
    mediaDir: join(root, name, 'media'),
  };
}
