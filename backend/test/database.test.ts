import { describe, expect, it } from 'vitest';
import { startHarness } from './harness.js';

/** Proves which database a run used, so a PostgreSQL run cannot quietly fall back to PGlite. */
describe('the test database', () => {
  it.runIf(process.env.VAWRA_TEST_DATABASE_URL)('is a new PostgreSQL database of its own', async () => {
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
});
