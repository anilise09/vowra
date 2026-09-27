import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Only the TypeScript sources; never the compiled copies in dist/.
    include: ['test/**/*.test.ts'],
    testTimeout: 30_000,
    // Each test starts its own in-memory PostgreSQL; slow on a busy machine.
    hookTimeout: 60_000,
  },
});
