import { emailProblems } from './email.js';
import { pushProblems } from './push.js';
import { s3Problems } from './s3.js';

export interface Config {
  enabled: boolean;
  /** VAWRA_ENV=production: refuses development switches and weak settings. */
  production: boolean;
  host: string;
  port: number;
  databaseUrl?: string;
  dataDir?: string;
  /** Processed photos, until a reviewed object store is chosen. */
  mediaDir: string;
  dataKey: Buffer;
  lookupKey: Buffer;
  accessTtlSeconds: number;
  proofTtlSeconds: number;
  reauthWindowSeconds: number;
  deletionGraceSeconds: number;
  devOutbox: boolean;
}

/** Settings that make no sense or are unsafe; the server will not start with any. */
export class ConfigError extends Error {
  constructor(readonly problems: string[]) {
    super(`Vawra cannot start:\n- ${problems.join('\n- ')}`);
  }
}

const positive = (problems: string[], name: string, raw: string | undefined, fallback: number) => {
  const value = Number(raw ?? fallback);
  if (!Number.isInteger(value) || value <= 0) problems.push(`${name} must be a whole number above 0.`);
  return value;
};

/**
 * The service ships switched off. It starts only with VAWRA_SERVER_ENABLED=1,
 * listens on 127.0.0.1 unless told otherwise, and refuses to run without keys.
 * With VAWRA_ENV=production it also refuses the development database, the
 * development sign-in outbox, direct calls and a default listen address.
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const problems: string[] = [];
  const production = env.VAWRA_ENV === 'production';
  if (env.VAWRA_ENV && !['production', 'development'].includes(env.VAWRA_ENV)) {
    problems.push('VAWRA_ENV must be "production" or "development".');
  }
  const key = (name: string) => {
    const value = env[name];
    if (!value) {
      problems.push(`${name} is required (32 random bytes, base64).`);
      return Buffer.alloc(0);
    }
    const bytes = Buffer.from(value, 'base64');
    if (bytes.length !== 32) problems.push(`${name} must be exactly 32 bytes, base64 (it is ${bytes.length}).`);
    return bytes;
  };
  const dataKey = key('VAWRA_DATA_KEY');
  const lookupKey = key('VAWRA_LOOKUP_KEY');
  if (dataKey.length === 32 && dataKey.equals(lookupKey)) {
    problems.push('VAWRA_DATA_KEY and VAWRA_LOOKUP_KEY must be different keys.');
  }
  const port = positive(problems, 'VAWRA_PORT', env.VAWRA_PORT, 8797);
  if (port > 65535) problems.push('VAWRA_PORT must be at most 65535.');
  const config: Config = {
    enabled: env.VAWRA_SERVER_ENABLED === '1',
    production,
    host: env.VAWRA_HOST ?? '127.0.0.1',
    port,
    databaseUrl: env.DATABASE_URL,
    dataDir: env.VAWRA_DATA_DIR ?? '.data/pglite',
    mediaDir: env.VAWRA_MEDIA_DIR ?? '.data/media',
    dataKey,
    lookupKey,
    accessTtlSeconds: positive(problems, 'VAWRA_ACCESS_TTL', env.VAWRA_ACCESS_TTL, 900),
    proofTtlSeconds: positive(problems, 'VAWRA_PROOF_TTL', env.VAWRA_PROOF_TTL, 600),
    reauthWindowSeconds: positive(problems, 'VAWRA_REAUTH_WINDOW', env.VAWRA_REAUTH_WINDOW, 600),
    // Placeholder until privacy counsel sets the recovery window.
    deletionGraceSeconds: positive(problems, 'VAWRA_DELETION_GRACE', env.VAWRA_DELETION_GRACE, 7 * 24 * 60 * 60),
    devOutbox: env.VAWRA_DEV_OUTBOX === '1',
  };
  if (production) {
    if (!config.databaseUrl) problems.push('Production needs DATABASE_URL (PostgreSQL); the development database is refused.');
    if (config.devOutbox) problems.push('VAWRA_DEV_OUTBOX writes sign-in codes to a file; it is refused in production.');
    if (env.VAWRA_CALLS_DEV_P2P === '1') {
      problems.push('VAWRA_CALLS_DEV_P2P shows each phone’s address to the other; production calls use a relay.');
    }
    if (!env.VAWRA_HOST) problems.push('Production needs VAWRA_HOST set explicitly (for example 0.0.0.0 in a container).');
    if (config.accessTtlSeconds > 3600) problems.push('VAWRA_ACCESS_TTL must be at most 3600 seconds in production.');
  }
  problems.push(...emailProblems(env, production));
  problems.push(...pushProblems(env));
  problems.push(...s3Problems(env, production));
  if (problems.length > 0) throw new ConfigError(problems);
  return config;
}
