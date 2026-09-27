export interface Config {
  enabled: boolean;
  host: string;
  port: number;
  databaseUrl?: string;
  dataDir?: string;
  dataKey: Buffer;
  lookupKey: Buffer;
  accessTtlSeconds: number;
  proofTtlSeconds: number;
  reauthWindowSeconds: number;
  deletionGraceSeconds: number;
  devOutbox: boolean;
}

/**
 * The service ships switched off. It starts only with VAWRA_SERVER_ENABLED=1,
 * listens on 127.0.0.1 unless told otherwise, and refuses to run without keys.
 */
export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const key = (name: string) => {
    const value = env[name];
    if (!value) throw new Error(`${name} is required (32 random bytes, base64).`);
    return Buffer.from(value, 'base64');
  };
  return {
    enabled: env.VAWRA_SERVER_ENABLED === '1',
    host: env.VAWRA_HOST ?? '127.0.0.1',
    port: Number(env.VAWRA_PORT ?? 8787),
    databaseUrl: env.DATABASE_URL,
    dataDir: env.VAWRA_DATA_DIR ?? '.data/pglite',
    dataKey: key('VAWRA_DATA_KEY'),
    lookupKey: key('VAWRA_LOOKUP_KEY'),
    accessTtlSeconds: Number(env.VAWRA_ACCESS_TTL ?? 900),
    proofTtlSeconds: Number(env.VAWRA_PROOF_TTL ?? 600),
    reauthWindowSeconds: Number(env.VAWRA_REAUTH_WINDOW ?? 600),
    // Placeholder until privacy counsel sets the recovery window.
    deletionGraceSeconds: Number(env.VAWRA_DELETION_GRACE ?? 7 * 24 * 60 * 60),
    devOutbox: env.VAWRA_DEV_OUTBOX === '1',
  };
}
