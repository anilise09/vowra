import { mkdirSync, readdirSync, readFileSync } from 'node:fs';
import type { PoolClient } from 'pg';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/** Minimal database surface the service needs; PGlite and pg both fit it. */
export interface Db {
  query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<T[]>;
  /** Runs `work` in one transaction; rolls back on any thrown error. */
  transaction<T>(work: (tx: Db) => Promise<T>): Promise<T>;
  close(): Promise<void>;
  /** PGlite only: the whole database as a gzipped tarball, for backups. */
  dump?(): Promise<Buffer>;
  /**
   * Receives NOTIFY messages on [channel], from every server using this
   * database. Returns the function that stops listening.
   */
  listen?(channel: string, onMessage: (payload: string) => void): Promise<() => Promise<void>>;
}

/** NOTIFY channels are identifiers; only plain names are accepted. */
const channelName = (channel: string) => {
  if (!/^[a-z_][a-z0-9_]{0,62}$/.test(channel)) throw new Error('bad channel name');
  return channel;
};

const migrationsDir = join(dirname(fileURLToPath(import.meta.url)), 'migrations');

const migrationFiles = () =>
  readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

/**
 * Applies new migrations in one transaction under an advisory lock, so several
 * servers starting at once never run the same migration twice. The lock comes
 * first: even "CREATE TABLE IF NOT EXISTS" collides when two servers run it at
 * once on an empty PostgreSQL database.
 */
export async function migrate(db: Db): Promise<void> {
  await db.transaction(async (tx) => {
    await tx.query('SELECT pg_advisory_xact_lock(7461722)');
    await tx.query('CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY)');
    const done = new Set(
      (await tx.query<{ name: string }>('SELECT name FROM schema_migrations')).map((r) => r.name),
    );
    for (const file of migrationFiles()) {
      if (done.has(file)) continue;
      const sql = readFileSync(join(migrationsDir, file), 'utf8');
      for (const statement of splitStatements(sql)) await tx.query(statement);
      await tx.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
    }
  });
}

/** Migrations this build ships that the database has not applied yet. */
export async function pendingMigrations(db: Db): Promise<string[]> {
  const done = new Set(
    (await db.query<{ name: string }>('SELECT name FROM schema_migrations')).map((r) => r.name),
  );
  return migrationFiles().filter((f) => !done.has(f));
}

/** Splits a migration into statements. Windows line endings are handled: a checkout may have them. */
export function splitStatements(sql: string): string[] {
  return sql
    .split(/\r?\n/)
    .map((line) => line.replace(/--.*$/, ''))
    .join('\n')
    .split(';')
    .map((s) => s.trim())
    .filter(Boolean);
}

/** In-process PostgreSQL (WASM). Used for development and tests; no install needed. */
export async function openPglite(dataDir?: string, restoreFrom?: Buffer): Promise<Db> {
  const { PGlite } = await import('@electric-sql/pglite');
  if (dataDir) mkdirSync(dataDir, { recursive: true });
  const options = restoreFrom ? { loadDataDir: new Blob([new Uint8Array(restoreFrom)]) } : {};
  const pg = dataDir ? new PGlite(dataDir, options) : new PGlite(options);
  await pg.waitReady;
  const wrap = (runner: { query: typeof pg.query }): Db => ({
    async query<T>(sql: string, params: unknown[] = []) {
      const result = await runner.query<T>(sql, params as never[]);
      return result.rows;
    },
    transaction: (work) => pg.transaction((tx) => work(wrap(tx as never))),
    close: () => pg.close(),
  });
  return {
    ...wrap(pg),
    dump: async () => Buffer.from(await (await pg.dumpDataDir('gzip')).arrayBuffer()),
    async listen(channel, onMessage) {
      const stop = await pg.listen(channelName(channel), onMessage);
      return async () => {
        await stop();
      };
    },
  };
}

/** A real PostgreSQL server, selected with DATABASE_URL. */
export async function openPostgres(url: string): Promise<Db> {
  const { default: pg } = await import('pg');
  const pool = new pg.Pool({ connectionString: url, max: 10 });
  const fromClient = (client: Pick<PoolClient, 'query'>): Db => ({
    async query<T>(sql: string, params: unknown[] = []) {
      return (await client.query(sql, params)).rows as T[];
    },
    async transaction<T>(work: (tx: Db) => Promise<T>) {
      const conn = await pool.connect();
      try {
        await conn.query('BEGIN');
        const result = await work(fromClient(conn as never));
        await conn.query('COMMIT');
        return result;
      } catch (error) {
        await conn.query('ROLLBACK');
        throw error;
      } finally {
        conn.release();
      }
    },
    close: () => pool.end(),
  });
  return {
    ...fromClient(pool),
    /**
     * A dedicated connection per channel (LISTEN belongs to one connection).
     * If it drops, it reconnects with back-off and listens again; messages sent
     * while it was down are missed, which the app's own refreshes cover.
     */
    async listen(channel, onMessage) {
      const name = channelName(channel);
      let stopped = false;
      let client: PoolClient | undefined;
      let attempt = 0;
      const connect = async (): Promise<void> => {
        if (stopped) return;
        try {
          const next = await pool.connect();
          client = next;
          next.on('notification', (message) => {
            if (message.channel === name) onMessage(message.payload ?? '');
          });
          next.on('error', () => {
            next.release(true);
            if (client === next) client = undefined;
            setTimeout(() => void connect(), Math.min(30_000, 500 * 2 ** attempt++)).unref();
          });
          await next.query(`LISTEN ${name}`);
          attempt = 0;
        } catch {
          setTimeout(() => void connect(), Math.min(30_000, 500 * 2 ** attempt++)).unref();
        }
      };
      await connect();
      return async () => {
        stopped = true;
        const current = client;
        client = undefined;
        if (current) {
          await current.query(`UNLISTEN ${name}`).catch(() => {});
          current.release();
        }
      };
    },
  };
}
