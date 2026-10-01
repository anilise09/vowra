import { createHash, createHmac } from 'node:crypto';
import type { MediaStore } from './media.js';

/**
 * Photos in any S3-compatible object store: Amazon S3, Cloudflare R2,
 * Backblaze B2, MinIO and others. Requests are signed with AWS Signature
 * Version 4, written out here rather than pulling in the whole AWS SDK.
 * Objects are private (no public URL ever exists); the server streams photos
 * after its own access checks, exactly as it does from disk.
 */
export interface S3Config {
  /** https://s3.ca-central-1.amazonaws.com, https://<account>.r2.cloudflarestorage.com, ... */
  endpoint: string;
  bucket: string;
  /** "auto" for R2; the bucket's region for S3. */
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  /** Key prefix inside the bucket, so photos can share a bucket safely. */
  prefix: string;
  /** Bucket in the host name (Amazon's default) or in the path (most others). */
  virtualHost: boolean;
  /** Ask the store to encrypt at rest with its own keys (Amazon S3: AES256). */
  serverSideEncryption?: string;
}

const sha256Hex = (data: string | Buffer) => createHash('sha256').update(data).digest('hex');
const hmac = (key: Buffer | string, data: string) => createHmac('sha256', key).update(data).digest();

/** RFC 3986 encoding as SigV4 wants it: every byte except unreserved characters. */
const encode = (value: string, keepSlash = false) => {
  const encoded = encodeURIComponent(value).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );
  return keepSlash ? encoded.replace(/%2F/g, '/') : encoded;
};

export interface SignedRequest {
  method: string;
  url: URL;
  headers: Record<string, string>;
}

/**
 * Signs a request (AWS Signature Version 4, header form). [headers] must
 * include host; x-amz-date and x-amz-content-sha256 are added.
 */
export function signV4(
  request: { method: string; url: URL; headers: Record<string, string>; body?: Buffer },
  credentials: { accessKeyId: string; secretAccessKey: string; region: string; service?: string },
  now: Date,
): SignedRequest {
  const service = credentials.service ?? 's3';
  const amzDate = now.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const day = amzDate.slice(0, 8);
  const payloadHash = request.headers['x-amz-content-sha256'] ?? sha256Hex(request.body ?? Buffer.alloc(0));
  const headers: Record<string, string> = {
    ...Object.fromEntries(Object.entries(request.headers).map(([k, v]) => [k.toLowerCase(), v.trim()])),
    'x-amz-date': amzDate,
    'x-amz-content-sha256': payloadHash,
  };
  const names = Object.keys(headers).sort();
  const canonicalHeaders = names.map((n) => `${n}:${headers[n]}\n`).join('');
  const signedHeaders = names.join(';');
  const query = [...request.url.searchParams.entries()]
    .map(([k, v]) => [encode(k), encode(v)])
    .sort(([a, x], [b, y]) => (a === b ? (x! < y! ? -1 : 1) : a! < b! ? -1 : 1))
    .map(([k, v]) => `${k}=${v}`)
    .join('&');
  const path = request.url.pathname
    .split('/')
    .map((segment) => encode(decodeURIComponent(segment)))
    .join('/');
  const canonicalRequest = [request.method, path, query, canonicalHeaders, signedHeaders, payloadHash].join('\n');
  const scope = `${day}/${credentials.region}/${service}/aws4_request`;
  const stringToSign = ['AWS4-HMAC-SHA256', amzDate, scope, sha256Hex(canonicalRequest)].join('\n');
  const key = hmac(hmac(hmac(hmac(`AWS4${credentials.secretAccessKey}`, day), credentials.region), service), 'aws4_request');
  const signature = createHmac('sha256', key).update(stringToSign).digest('hex');
  return {
    method: request.method,
    url: request.url,
    headers: {
      ...headers,
      authorization: `AWS4-HMAC-SHA256 Credential=${credentials.accessKeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
    },
  };
}

const safeId = (id: string) => {
  if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error('bad media id');
  return id;
};

export class S3MediaStore implements MediaStore {
  constructor(
    private readonly config: S3Config,
    private readonly now = () => new Date(),
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  private url(id: string): URL {
    const base = new URL(this.config.endpoint);
    const key = `${this.config.prefix}${safeId(id)}.webp`;
    return this.config.virtualHost
      ? new URL(`${base.protocol}//${this.config.bucket}.${base.host}/${encode(key, true)}`)
      : new URL(`${base.origin}/${encode(this.config.bucket)}/${encode(key, true)}`);
  }

  private async send(method: string, id: string, body?: Buffer, extra: Record<string, string> = {}) {
    const url = this.url(id);
    // One retry for a network hiccup or a 5xx; anything else is an answer.
    for (let attempt = 0; ; attempt++) {
      const signed = signV4({ method, url, headers: { host: url.host, ...extra }, body }, this.config, this.now());
      try {
        const res = await this.fetcher(url, {
          method,
          headers: signed.headers,
          body: body ? new Uint8Array(body) : undefined,
        });
        if (res.status >= 500 && attempt === 0) continue;
        return res;
      } catch (error) {
        if (attempt === 0) continue;
        throw error;
      }
    }
  }

  async put(id: string, bytes: Buffer) {
    const res = await this.send('PUT', id, bytes, {
      'content-type': 'image/webp',
      'cache-control': 'private, no-store',
      ...(this.config.serverSideEncryption
        ? { 'x-amz-server-side-encryption': this.config.serverSideEncryption }
        : {}),
    });
    if (!res.ok) throw new Error(`photo store refused the upload: ${res.status}`);
  }

  async get(id: string) {
    const res = await this.send('GET', id);
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`photo store read failed: ${res.status}`);
    return Buffer.from(await res.arrayBuffer());
  }

  async delete(id: string) {
    const res = await this.send('DELETE', id);
    // Deleting something already gone is fine.
    if (!res.ok && res.status !== 404) throw new Error(`photo store delete failed: ${res.status}`);
  }
}

const s3Names = ['VAWRA_S3_ENDPOINT', 'VAWRA_S3_BUCKET', 'VAWRA_S3_REGION', 'VAWRA_S3_ACCESS_KEY_ID', 'VAWRA_S3_SECRET_ACCESS_KEY'];

export function s3Problems(env: NodeJS.ProcessEnv, production: boolean): string[] {
  const set = s3Names.filter((n) => env[n]);
  if (set.length === 0) return [];
  const problems: string[] = [];
  if (set.length < s3Names.length) {
    problems.push(`Photo storage needs all of ${s3Names.join(', ')}; missing ${s3Names.filter((n) => !env[n]).join(', ')}.`);
  }
  if (env.VAWRA_S3_ENDPOINT) {
    try {
      const url = new URL(env.VAWRA_S3_ENDPOINT);
      if (production && url.protocol !== 'https:') problems.push('VAWRA_S3_ENDPOINT must use https:// in production.');
      if (url.pathname !== '/' || url.search) problems.push('VAWRA_S3_ENDPOINT is the service address only, without a path.');
    } catch {
      problems.push('VAWRA_S3_ENDPOINT is not a valid URL.');
    }
  }
  if (env.VAWRA_S3_BUCKET && !/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(env.VAWRA_S3_BUCKET)) {
    problems.push('VAWRA_S3_BUCKET is not a valid bucket name.');
  }
  if (env.VAWRA_S3_PREFIX && !/^[\w.-]+(\/[\w.-]+)*\/$/.test(env.VAWRA_S3_PREFIX)) {
    problems.push('VAWRA_S3_PREFIX must look like "photos/" (letters, digits, dots, dashes; ends with a slash).');
  }
  return problems;
}

export function s3ConfigFrom(env: NodeJS.ProcessEnv): S3Config | null {
  if (!s3Names.every((n) => env[n])) return null;
  const endpoint = env.VAWRA_S3_ENDPOINT!;
  return {
    endpoint,
    bucket: env.VAWRA_S3_BUCKET!,
    region: env.VAWRA_S3_REGION!,
    accessKeyId: env.VAWRA_S3_ACCESS_KEY_ID!,
    secretAccessKey: env.VAWRA_S3_SECRET_ACCESS_KEY!,
    prefix: env.VAWRA_S3_PREFIX ?? '',
    virtualHost: env.VAWRA_S3_VIRTUAL_HOST
      ? env.VAWRA_S3_VIRTUAL_HOST === '1'
      : new URL(endpoint).host.endsWith('amazonaws.com'),
    serverSideEncryption: env.VAWRA_S3_SSE || undefined,
  };
}
