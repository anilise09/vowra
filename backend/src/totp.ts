import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * Time-based one-time passwords (RFC 6238), the six-digit codes authenticator
 * apps show: HMAC-SHA1, 30-second steps. One step either side is accepted for
 * clock drift, and a step already used is refused, so a code works once.
 */
export const totpRules = { digits: 6, stepSeconds: 30, window: 1 };

const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function base32Encode(bytes: Buffer): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += alphabet[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += alphabet[(value << (5 - bits)) & 31];
  return out;
}

export function base32Decode(text: string): Buffer {
  const clean = text.replace(/[\s=-]/g, '').toUpperCase();
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const char of clean) {
    const index = alphabet.indexOf(char);
    if (index < 0) throw new Error('not base32');
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

/** A new secret: 20 random bytes, as authenticator apps expect. */
export const newTotpSecret = () => base32Encode(randomBytes(20));

export const stepAt = (time: Date) => Math.floor(time.getTime() / 1000 / totpRules.stepSeconds);

export function totpCode(secret: string, step: number): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const hmac = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const offset = hmac[hmac.length - 1]! & 15;
  const binary = hmac.readUInt32BE(offset) & 0x7fffffff;
  return String(binary % 10 ** totpRules.digits).padStart(totpRules.digits, '0');
}

/**
 * Returns the step the code belongs to, or null. A step at or before
 * [lastUsedStep] is refused, so the same code (or an older one) cannot be replayed.
 */
export function verifyTotp(secret: string, code: string, time: Date, lastUsedStep: number | null): number | null {
  if (!/^\d{6}$/.test(code)) return null;
  const now = stepAt(time);
  for (let offset = -totpRules.window; offset <= totpRules.window; offset++) {
    const step = now + offset;
    if (lastUsedStep !== null && step <= lastUsedStep) continue;
    const expected = Buffer.from(totpCode(secret, step));
    if (timingSafeEqual(expected, Buffer.from(code))) return step;
  }
  return null;
}

/** The link authenticator apps read from a QR code or accept pasted. */
export function otpauthUri(secret: string, account: string, issuer = 'Vawra Moderation'): string {
  const label = encodeURIComponent(`${issuer}:${account}`);
  const params = new URLSearchParams({
    secret,
    issuer,
    algorithm: 'SHA1',
    digits: String(totpRules.digits),
    period: String(totpRules.stepSeconds),
  });
  return `otpauth://totp/${label}?${params.toString()}`;
}
