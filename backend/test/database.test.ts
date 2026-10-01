import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { migrate, openPostgres, pendingMigrations } from '../src/db.js';
import { startHarness } from './harness.js';

const postgres = process.env.VAWRA_TEST_DATABASE_URL;

/** Runs SQL on the server as the test superuser, outside any test database. */
async function admin(sql: string) {
  const { default: pg } = await import('pg');
  const client = new pg.Client({ connectionString: postgres });
  await client.connect();
  try {
    await client.query(sql);
  } finally {
    await client.end();
  }
}

/** Proves which database a run used, so a PostgreSQL run cannot quietly fall back to PGlite. */
describe('the test database', () => {
  it.runIf(postgres)('is a new PostgreSQL database of its own', async () => {
    const h = await startHarness();
    try {
      const [row] = await h.db.query<{ name: string; version: string }>(
        'SELECT current_database() AS name, version() AS version',
      );
      expect(row!.name).toMatch(/^vawra_test_[0-9a-f]{16}$/);
      expect(h.db.dump).toBeUndefined(); // PGlite's own backup; a real server has none
    } finally {
      await h.close();
    }
  });

  // Found by starting two servers at once on an empty database: both created the
  // migrations table outside the lock and one crashed on start.
  it.runIf(postgres)('several servers starting at once on an empty database all migrate it', async () => {
    // A race: several rounds of eight, each on a new empty database.
    for (let round = 0; round < 5; round++) {
      const name = `vawra_test_${randomBytes(8).toString('hex')}`;
      await admin(`CREATE DATABASE ${name}`);
      const url = new URL(postgres!);
      url.pathname = `/${name}`;
      const servers = await Promise.all(Array.from({ length: 8 }, () => openPostgres(url.toString())));
      try {
        const results = await Promise.allSettled(servers.map((db) => migrate(db)));
        expect(results.filter((r) => r.status === 'rejected')).toEqual([]);
        expect(await pendingMigrations(servers[0]!)).toEqual([]);
      } finally {
        await Promise.all(servers.map((db) => db.close()));
        await admin(`DROP DATABASE IF EXISTS ${name} WITH (FORCE)`);
      }
    }
  }, 60_000);
});
