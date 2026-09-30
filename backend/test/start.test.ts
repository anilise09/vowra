import { randomBytes } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { ConfigError, loadConfig } from '../src/config.js';
import { migrate, openPglite, pendingMigrations } from '../src/db.js';
import { type Running, startServer } from '../src/start.js';
import { type Harness, member, startHarness } from './harness.js';

const key = () => randomBytes(32).toString('base64');
const base = () => ({ VAWRA_DATA_KEY: key(), VAWRA_LOOKUP_KEY: key() });

const problemsOf = (env: NodeJS.ProcessEnv) => {
  try {
    loadConfig(env);
    return [];
  } catch (error) {
    expect(error).toBeInstanceOf(ConfigError);
    return (error as ConfigError).problems;
  }
};

describe('settings', () => {
  it('development starts with keys alone', () => {
    const config = loadConfig(base());
    expect(config).toMatchObject({ production: false, host: '127.0.0.1', port: 8797 });
  });

  it('refuses weak or missing keys and nonsense numbers, all at once', () => {
    const problems = problemsOf({
      VAWRA_DATA_KEY: Buffer.alloc(16).toString('base64'),
      VAWRA_PORT: '99999',
      VAWRA_ACCESS_TTL: 'soon',
    });
    expect(problems.join('\n')).toMatch(/VAWRA_DATA_KEY must be exactly 32 bytes/);
    expect(problems.join('\n')).toMatch(/VAWRA_LOOKUP_KEY is required/);
    expect(problems.join('\n')).toMatch(/VAWRA_PORT must be at most 65535/);
    expect(problems.join('\n')).toMatch(/VAWRA_ACCESS_TTL must be a whole number/);
    const same = key();
    expect(problemsOf({ VAWRA_DATA_KEY: same, VAWRA_LOOKUP_KEY: same })).toEqual([
      'VAWRA_DATA_KEY and VAWRA_LOOKUP_KEY must be different keys.',
    ]);
  });

  it('production refuses every development switch', () => {
    const problems = problemsOf({
      ...base(),
      VAWRA_ENV: 'production',
      VAWRA_DEV_OUTBOX: '1',
      VAWRA_CALLS_DEV_P2P: '1',
      VAWRA_ACCESS_TTL: '86400',
    }).join('\n');
    expect(problems).toMatch(/DATABASE_URL/);
    expect(problems).toMatch(/VAWRA_DEV_OUTBOX/);
    expect(problems).toMatch(/VAWRA_CALLS_DEV_P2P/);
    expect(problems).toMatch(/VAWRA_HOST/);
    expect(problems).toMatch(/VAWRA_TRUST_PROXY/);
    expect(problems).toMatch(/VAWRA_ACCESS_TTL must be at most 3600/);
    expect(problems).toMatch(/Production needs VAWRA_SMTP_URL/);
    // Error messages never repeat a secret.
    expect(problems).not.toContain(base().VAWRA_DATA_KEY);
  });

  it('production with the right settings starts', () => {
    const config = loadConfig({
      ...base(),
      VAWRA_ENV: 'production',
      DATABASE_URL: 'postgres://vawra@db.internal/vawra',
      VAWRA_HOST: '0.0.0.0',
      VAWRA_SMTP_URL: 'smtps://mailer:secret@smtp.example.com:465',
      VAWRA_EMAIL_FROM: 'Vawra <no-reply@example.com>',
      VAWRA_TRUST_PROXY: '10.0.0.0/8',
    });
    expect(config).toMatchObject({ production: true, trustedProxies: ['10.0.0.0/8'] });
  });

  it('never allows a production setting that trusts every forwarded header', () => {
    expect(problemsOf({ ...base(), VAWRA_TRUST_PROXY: '*' }).join()).toMatch(/never trust everyone/);
  });

  it('rejects an unknown environment name', () => {
    expect(problemsOf({ ...base(), VAWRA_ENV: 'prod' }).join()).toMatch(/VAWRA_ENV must be/);
  });
});

describe('production transport', () => {
  it('trusts HTTPS only from the configured proxy and sends HSTS', async () => {
    const h = await startHarness({
      appOptions: { enforceHttps: true, trustedProxies: ['127.0.0.1'] },
    });
    try {
      const plain = await h.app.inject({ method: 'GET', url: '/v1/discovery' });
      expect(plain.statusCode).toBe(426);
      expect(plain.json().error).toBe('https_required');

      const spoofed = await h.app.inject({
        method: 'GET',
        url: '/v1/discovery',
        remoteAddress: '203.0.113.9',
        headers: { 'x-forwarded-proto': 'https' },
      });
      expect(spoofed.statusCode).toBe(426);

      const secure = await h.app.inject({
        method: 'GET',
        url: '/v1/discovery',
        remoteAddress: '127.0.0.1',
        headers: { 'x-forwarded-proto': 'https' },
      });
      expect(secure.statusCode).toBe(401);
      expect(secure.headers['strict-transport-security']).toBe('max-age=31536000');

      // Private orchestrator probes do not need to loop through the TLS proxy.
      expect((await h.app.inject({ method: 'GET', url: '/v1/health' })).statusCode).toBe(200);
    } finally {
      await h.close();
    }
  });
});

describe('migrations', () => {
  it('apply once, and running them again changes nothing', async () => {
    const db = await openPglite();
    await migrate(db);
    expect(await pendingMigrations(db)).toEqual([]);
    const [before] = await db.query<{ n: number }>('SELECT count(*)::int AS n FROM schema_migrations');
    await migrate(db);
    const [after] = await db.query<{ n: number }>('SELECT count(*)::int AS n FROM schema_migrations');
    expect(after!.n).toBe(before!.n);
    await db.query("DELETE FROM schema_migrations WHERE name = '011_calls.sql'");
    expect(await pendingMigrations(db)).toEqual(['011_calls.sql']);
    await db.close();
  });
});

describe('the running server', () => {
  let running: Running | undefined;
  let dir: string | undefined;
  afterEach(async () => {
    await running?.close();
    running = undefined;
    if (dir) rmSync(dir, { recursive: true, force: true });
    dir = undefined;
  });

  const outbox: Harness['outbox'] = [];
  const start = async (drainMs = 0) => {
    dir = mkdtempSync(join(tmpdir(), 'vawra-start-'));
    const config = { ...loadConfig(base()), port: 0, dataDir: undefined, mediaDir: join(dir, 'media') };
    const delivery = { sendProof: async (email: string, proof: string, purpose: string) => void outbox.push({ email, proof, purpose }) };
    running = await startServer(config, {}, { logger: false, drainMs, delivery });
    return `http://127.0.0.1:${running.port}`;
  };
  /** The harness helpers, pointed at the real running server. */
  const asHarness = () => ({ app: running!.app, db: running!.db, outbox }) as unknown as Harness;

  it('is alive and ready once migrated', async () => {
    const url = await start();
    expect(await (await fetch(`${url}/v1/health`)).json()).toEqual({ ok: true });
    const ready = await fetch(`${url}/v1/ready`);
    expect(ready.status).toBe(200);
    expect(await ready.json()).toEqual({ ready: true });
  });

  it('is not ready while a migration is missing', async () => {
    const url = await start();
    await running!.db.query("DELETE FROM schema_migrations WHERE name = '011_calls.sql'");
    const ready = await fetch(`${url}/v1/ready`);
    expect(ready.status).toBe(503);
    expect((await ready.json()).reason).toBe('migrations_pending');
  });

  it('stops being ready first, then stops cleanly with a live stream open', async () => {
    const url = await start(300);
    // An open live-update stream must not hold the shutdown up.
    const ana = await member(asHarness(), 'Ana');
    const stream = await fetch(`${url}/v1/events`, { headers: ana.auth });
    expect(stream.status).toBe(200);
    const reader = stream.body!.getReader();
    expect(new TextDecoder().decode((await reader.read()).value)).toContain('connected');
    const closing = running!.close();
    const ready = await fetch(`${url}/v1/ready`);
    expect(ready.status).toBe(503);
    expect((await ready.json()).reason).toBe('shutting_down');
    const started = Date.now();
    await closing;
    expect(Date.now() - started).toBeLessThan(5000);
    await expect(fetch(`${url}/v1/health`)).rejects.toThrow();
    // The stream was ended by the server, not left hanging.
    let done = false;
    while (!done) done = (await reader.read()).done;
    running = undefined;
  });
});

describe('migration files', () => {
  it('split the same with Windows line endings, comments and all', async () => {
    const { splitStatements } = await import('../src/db.js');
    const sql = '-- A comment; with a semicolon, no statement\nCREATE TABLE a (x int);\n-- another\nCREATE INDEX a_x ON a (x);\n';
    const unix = splitStatements(sql);
    expect(unix).toEqual(['CREATE TABLE a (x int)', 'CREATE INDEX a_x ON a (x)']);
    expect(splitStatements(sql.replace(/\n/g, '\r\n'))).toEqual(unix);
  });
});
