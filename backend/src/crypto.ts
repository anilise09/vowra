import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes } from 'node:crypto';

/** Opaque, unguessable token for sessions and proofs (256 bits, URL-safe). */
export const newToken = (): string => randomBytes(32).toString('base64url');

/** Tokens and proofs are stored only as SHA-256 hashes. */
export const hashToken = (token: string): string =>
  createHash('sha256').update(token).digest('base64url');

/** PKCE S256: base64url(sha256(verifier)). */
export const pkceChallenge = (verifier: string): string =>
  createHash('sha256').update(verifier).digest('base64url');

export class Sealer {
  constructor(
    private readonly dataKey: Buffer,
    private readonly lookupKey: Buffer,
  ) {
    if (dataKey.length !== 32 || lookupKey.length !== 32) {
      throw new Error('VAWRA_DATA_KEY and VAWRA_LOOKUP_KEY must each be 32 bytes (base64).');
    }
  }

  /** Keyed hash for finding an email without storing it in clear. */
  lookup(value: string): string {
    return createHmac('sha256', this.lookupKey).update(value).digest('base64url');
  }

  seal(value: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.dataKey, iv);
    const body = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
    return [iv, cipher.getAuthTag(), body].map((b) => b.toString('base64url')).join('.');
  }

  open(sealed: string): string {
    const [iv, tag, body] = sealed.split('.').map((p) => Buffer.from(p, 'base64url'));
    if (!iv || !tag || !body) throw new Error('malformed sealed value');
    const decipher = createDecipheriv('aes-256-gcm', this.dataKey, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(body), decipher.final()]).toString('utf8');
  }
}
