import { appendFileSync, mkdirSync } from 'node:fs';
import type { FastifyInstance } from 'fastify';
import { buildApp } from './app.js';
import { callConfigFrom, SignalBox } from './calls.js';
import type { Config } from './config.js';
import type { Delivery } from './context.js';
import { Sealer } from './crypto.js';
import { emailConfigFrom, SmtpDelivery } from './email.js';
import { type Db, migrate, openPglite, openPostgres } from './db.js';
import { runDueDeletions } from './jobs/deletions.js';
import { runRetention } from './jobs/retention.js';
import { DiskMediaStore, MediaGrants } from './media.js';
import { MemoryNudgeBus } from './nudges.js';
import { Notifier, pushSendersFrom } from './push.js';

export interface Running {
  app: FastifyInstance;
  db: Db;
  /** The port actually listened on (useful with port 0 in tests). */
  port: number;
  /**
   * Graceful stop: readiness fails first, open live-update streams end, requests
   * in flight finish, the hourly job stops, then the database closes.
   */
  close(): Promise<void>;
}

/** SMTP when configured; otherwise the development outbox writes codes to a local file. */
function deliveryFor(config: Config, env: NodeJS.ProcessEnv): Delivery {
  const email = emailConfigFrom(env);
  if (email) return new SmtpDelivery(email, config.proofTtlSeconds);
  if (config.devOutbox) {
    return {
      async sendProof(email, proof, purpose) {
        mkdirSync('.data', { recursive: true });
        appendFileSync('.data/outbox.log', `${new Date().toISOString()} ${purpose} ${email} ${proof}\n`);
      },
    };
  }
  return {
    async sendProof() {
      throw new Error('No sign-in delivery provider is configured.');
    },
  };
}

export async function startServer(
  config: Config,
  env: NodeJS.ProcessEnv = process.env,
  options: {
    logger?: boolean;
    delivery?: Delivery;
    sweepEveryMs?: number;
    /** How long readiness fails before the server stops listening, so traffic moves away first. */
    drainMs?: number;
  } = {},
): Promise<Running> {
  const db = config.databaseUrl ? await openPostgres(config.databaseUrl) : await openPglite(config.dataDir);
  await migrate(db);

  // Local disk until a reviewed object store is chosen.
  const media = new DiskMediaStore(config.mediaDir);
  let draining = false;
  const sealer = new Sealer(config.dataKey, config.lookupKey);
  const nudges = new MemoryNudgeBus();
  let log: (message: string, detail?: object) => void = () => {};
  const notifier = new Notifier(db, sealer, nudges, pushSendersFrom(env), () => new Date(), (m, d) => log(m, d));
  const app = buildApp(
    {
      db,
      sealer,
      clock: { now: () => new Date() },
      delivery: options.delivery ?? deliveryFor(config, env),
      nudges,
      notifier,
      media,
      grants: new MediaGrants(config.dataKey),
      signals: new SignalBox(),
      callConfig: callConfigFrom(env),
      accessTtlSeconds: config.accessTtlSeconds,
      proofTtlSeconds: config.proofTtlSeconds,
      reauthWindowSeconds: config.reauthWindowSeconds,
      deletionGraceSeconds: config.deletionGraceSeconds,
    },
    { logger: options.logger ?? true, isDraining: () => draining },
  );
  log = (message, detail) => app.log.warn(detail ?? {}, message);
  await app.listen({ host: config.host, port: config.port });
  const address = app.server.address();
  const port = typeof address === 'object' && address ? address.port : config.port;

  // Scheduled deletions and retention run at start and then hourly.
  const clock = { now: () => new Date() };
  let sweeping: Promise<unknown> = Promise.resolve();
  const sweep = () => {
    sweeping = runDueDeletions(db, clock, media)
      .then((n) => n > 0 && app.log.info({ deleted: n }, 'scheduled deletions completed'))
      .then(() => runRetention(db, clock))
      .then((removed) => app.log.info({ removed }, 'retention sweep completed'))
      .catch((err: Error) => app.log.error({ err: { message: err.message } }, 'scheduled job failed'));
    return sweeping;
  };
  await sweep();
  const timer = setInterval(sweep, options.sweepEveryMs ?? 60 * 60 * 1000);
  timer.unref();

  let closing: Promise<void> | undefined;
  return {
    app,
    db,
    port,
    close() {
      closing ??= (async () => {
        draining = true;
        clearInterval(timer);
        if (options.drainMs) await new Promise((resolve) => setTimeout(resolve, options.drainMs));
        await app.close();
        await notifier.idle();
        await sweeping;
        await db.close();
      })();
      return closing;
    },
  };
}
