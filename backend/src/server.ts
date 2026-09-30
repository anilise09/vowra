import { ConfigError, loadConfig } from './config.js';
import { startServer } from './start.js';

let config;
try {
  config = loadConfig();
} catch (error) {
  // Every problem at once, never a secret's value.
  console.error(error instanceof ConfigError ? error.message : String(error));
  process.exit(1);
}
if (!config.enabled) {
  console.error('Vawra server is switched off. Set VAWRA_SERVER_ENABLED=1 to start it.');
  process.exit(1);
}

const drainSeconds = Number(process.env.VAWRA_DRAIN_SECONDS ?? (config.production ? 10 : 0));
const running = await startServer(config, process.env, { drainMs: drainSeconds * 1000 });

// A platform stops a server with SIGTERM: finish what is in flight, then exit.
let stopping = false;
for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, () => {
    if (stopping) return;
    stopping = true;
    running.app.log.info({ signal }, 'shutting down');
    const force = setTimeout(() => process.exit(1), drainSeconds * 1000 + 20_000);
    force.unref();
    running
      .close()
      .then(() => process.exit(0))
      .catch(() => process.exit(1));
  });
}
