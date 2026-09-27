import { mkdirSync, appendFileSync } from 'node:fs';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { Sealer } from './crypto.js';
import { migrate, openPglite, openPostgres } from './db.js';
import type { Delivery } from './context.js';

const config = loadConfig();
if (!config.enabled) {
  console.error('Vawra server is switched off. Set VAWRA_SERVER_ENABLED=1 to start it.');
  process.exit(1);
}

// No email provider is chosen yet. The development outbox writes proofs to a
// local file so a developer can sign in; it is refused unless explicitly on.
const delivery: Delivery = config.devOutbox
  ? {
      async sendProof(email, proof, purpose) {
        mkdirSync('.data', { recursive: true });
        appendFileSync('.data/outbox.log', `${new Date().toISOString()} ${purpose} ${email} ${proof}\n`);
      },
    }
  : {
      async sendProof() {
        throw new Error('No sign-in delivery provider is configured.');
      },
    };

const db = config.databaseUrl
  ? await openPostgres(config.databaseUrl)
  : await openPglite(config.dataDir);
await migrate(db);

const app = buildApp(
  {
    db,
    sealer: new Sealer(config.dataKey, config.lookupKey),
    clock: { now: () => new Date() },
    delivery,
    accessTtlSeconds: config.accessTtlSeconds,
    proofTtlSeconds: config.proofTtlSeconds,
  },
  { logger: true },
);
await app.listen({ host: config.host, port: config.port });
