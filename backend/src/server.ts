import { callConfigFrom, SignalBox } from './calls.js';
import { mkdirSync, appendFileSync } from 'node:fs';
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { Sealer } from './crypto.js';
import { migrate, openPglite, openPostgres } from './db.js';
import type { Delivery } from './context.js';
import { runDueDeletions } from './jobs/deletions.js';
import { runRetention } from './jobs/retention.js';
import { MemoryNudgeBus } from './nudges.js';
import { DiskMediaStore, MediaGrants } from './media.js';

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

// Local disk until a reviewed object store is chosen.
const media = new DiskMediaStore(config.mediaDir);

const app = buildApp(
  {
    db,
    sealer: new Sealer(config.dataKey, config.lookupKey),
    clock: { now: () => new Date() },
    delivery,
    nudges: new MemoryNudgeBus(),
    media,
    grants: new MediaGrants(config.dataKey),
    signals: new SignalBox(),
    callConfig: callConfigFrom(process.env),
    accessTtlSeconds: config.accessTtlSeconds,
    proofTtlSeconds: config.proofTtlSeconds,
    reauthWindowSeconds: config.reauthWindowSeconds,
    deletionGraceSeconds: config.deletionGraceSeconds,
  },
  { logger: true },
);
await app.listen({ host: config.host, port: config.port });

// Scheduled deletions run at start and then hourly.
const clock = { now: () => new Date() };
const sweep = () =>
  runDueDeletions(db, clock, media)
    .then((n) => n > 0 && app.log.info({ deleted: n }, 'scheduled deletions completed'))
    .then(() => runRetention(db, clock))
    .then((removed) => app.log.info({ removed }, 'retention sweep completed'))
    .catch((err: Error) => app.log.error({ err: { message: err.message } }, 'scheduled job failed'));
await sweep();
setInterval(sweep, 60 * 60 * 1000).unref();
