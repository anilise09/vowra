import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // Only the TypeScript sources; never the compiled copies in dist/.
    include: ['test/**/*.test.ts'],
    testTimeout: 30_000,
    // Each test starts its own in-memory PostgreSQL; slow on a busy machine.
    hookTimeout: 60_000,
    // Ten test files each starting a database at once starved each other on this laptop
    // (a 3 s test timed out at 30 s); four at a time is faster overall and reliable.
    maxWorkers: 4,
  },
});
