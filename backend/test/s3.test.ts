import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterEach, describe, expect, it } from 'vitest';
import { S3MediaStore, s3ConfigFrom, s3Problems, signV4 } from '../src/s3.js';

const signatureOf = (authorization: string) => /Signature=([0-9a-f]+)/.exec(authorization)![1];

describe('AWS Signature Version 4', () => {
  // The worked examples in Amazon's S3 documentation ("Signature Calculations for the
  // Authorization Header"), with their documented example credentials.
  const credentials = {
    accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
    secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    region: 'us-east-1',
  };
  const when = new Date('2013-05-24T00:00:00Z');
  const emptyHash = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  it('GET Object matches the documented signature', () => {
    const signed = signV4(
      {
        method: 'GET',
        url: new URL('https://examplebucket.s3.amazonaws.com/test.txt'),
        headers: { host: 'examplebucket.s3.amazonaws.com', range: 'bytes=0-9', 'x-amz-content-sha256': emptyHash },
      },
      credentials,
      when,
    );
    expect(signed.headers.authorization).toContain(
      'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request',
    );
    expect(signed.headers.authorization).toContain('SignedHeaders=host;range;x-amz-content-sha256;x-amz-date');
    expect(signatureOf(signed.headers.authorization!)).toBe(
      'f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
    );
  });

  it('GET Bucket lifecycle (a bare query key) matches the documented signature', () => {
    const signed = signV4(
      {
        method: 'GET',
        url: new URL('https://examplebucket.s3.amazonaws.com/?lifecycle'),
        headers: { host: 'examplebucket.s3.amazonaws.com', 'x-amz-content-sha256': emptyHash },
      },
      credentials,
      when,
    );
    expect(signatureOf(signed.headers.authorization!)).toBe(
      'fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543',
    );
  });

  it('List Objects (sorted query parameters) matches the documented signature', () => {
    const signed = signV4(
      {
        method: 'GET',
        url: new URL('https://examplebucket.s3.amazonaws.com/?max-keys=2&prefix=J'),
        headers: { host: 'examplebucket.s3.amazonaws.com', 'x-amz-content-sha256': emptyHash },
      },
      credentials,
      when,
    );
    expect(signatureOf(signed.headers.authorization!)).toBe(
      '34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7',
    );
  });

  it('sorts query parameters itself: the same request in another order signs the same', () => {
    const signed = signV4(
      {
        method: 'GET',
        url: new URL('https://examplebucket.s3.amazonaws.com/?prefix=J&max-keys=2'),
        headers: { host: 'examplebucket.s3.amazonaws.com', 'x-amz-content-sha256': emptyHash },
      },
      credentials,
      when,
    );
    expect(signatureOf(signed.headers.authorization!)).toBe(
      '34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7',
    );
  });
});

describe('photos in an S3-compatible store', () => {
  let server: Server | undefined;
  afterEach(async () => {
    await new Promise<void>((resolve) => (server ? server.close(() => resolve()) : resolve()));
    server = undefined;
  });

  /** A stand-in object store: keeps objects by path, can fail the next request once. */
  async function fakeS3() {
    const objects = new Map<string, { body: Buffer; headers: Record<string, unknown> }>();
    const log: { method: string; path: string; headers: Record<string, unknown> }[] = [];
    const state = { failNext: false };
    server = createServer((req, res) => {
      const chunks: Buffer[] = [];
      req.on('data', (c: Buffer) => chunks.push(c));
      req.on('end', () => {
        log.push({ method: req.method!, path: req.url!, headers: req.headers });
        if (state.failNext) {
          state.failNext = false;
          res.statusCode = 503;
          return res.end();
        }
        if (req.method === 'PUT') {
          objects.set(req.url!, { body: Buffer.concat(chunks), headers: req.headers });
          return res.end();
        }
        const object = objects.get(req.url!);
        if (req.method === 'DELETE') {
          objects.delete(req.url!);
          res.statusCode = 204;
          return res.end();
        }
        if (!object) {
          res.statusCode = 404;
          return res.end('<Error><Code>NoSuchKey</Code></Error>');
        }
        res.end(object.body);
      });
    });
    await new Promise<void>((resolve) => server!.listen(0, '127.0.0.1', () => resolve()));
    const endpoint = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    return { objects, log, state, endpoint };
  }

  const id = '1b4e28ba-2fa1-11d2-883f-0016d3cca427';

  it('stores, reads and deletes privately, under the prefix, signed', async () => {
    const s3 = await fakeS3();
    const store = new S3MediaStore({
      endpoint: s3.endpoint,
      bucket: 'vawra-photos',
      region: 'auto',
      accessKeyId: 'KEY',
      secretAccessKey: 'SECRET',
      prefix: 'photos/',
      virtualHost: false,
      serverSideEncryption: 'AES256',
    });
    await store.put(id, Buffer.from('webp-bytes'));
    const key = `/vawra-photos/photos/${id}.webp`;
    expect([...s3.objects.keys()]).toEqual([key]);
    const put = s3.objects.get(key)!.headers;
    expect(put['content-type']).toBe('image/webp');
    expect(put['cache-control']).toBe('private, no-store');
    expect(put['x-amz-server-side-encryption']).toBe('AES256');
    expect(String(put.authorization)).toMatch(/^AWS4-HMAC-SHA256 Credential=KEY\/\d{8}\/auto\/s3\/aws4_request/);
    // The content hash is signed, so a changed body would not be accepted.
    expect(put['x-amz-content-sha256']).toMatch(/^[0-9a-f]{64}$/);
    expect((await store.get(id))!.toString()).toBe('webp-bytes');
    await store.delete(id);
    expect(await store.get(id)).toBeNull();
    // Deleting again is not an error.
    await store.delete(id);
  });

  it('retries once after a server error, and refuses a bad id', async () => {
    const s3 = await fakeS3();
    const store = new S3MediaStore(s3ConfigFrom({
      VAWRA_S3_ENDPOINT: s3.endpoint,
      VAWRA_S3_BUCKET: 'vawra-photos',
      VAWRA_S3_REGION: 'auto',
      VAWRA_S3_ACCESS_KEY_ID: 'KEY',
      VAWRA_S3_SECRET_ACCESS_KEY: 'SECRET',
    })!);
    s3.state.failNext = true;
    await store.put(id, Buffer.from('x'));
    expect(s3.log.map((l) => l.method)).toEqual(['PUT', 'PUT']);
    await expect(store.get('../../etc/passwd')).rejects.toThrow('bad media id');
  });

  it('puts the bucket in the host name for Amazon, in the path elsewhere', () => {
    const base = {
      VAWRA_S3_BUCKET: 'vawra-photos',
      VAWRA_S3_REGION: 'ca-central-1',
      VAWRA_S3_ACCESS_KEY_ID: 'K',
      VAWRA_S3_SECRET_ACCESS_KEY: 'S',
    };
    expect(s3ConfigFrom({ ...base, VAWRA_S3_ENDPOINT: 'https://s3.ca-central-1.amazonaws.com' })!.virtualHost).toBe(true);
    expect(s3ConfigFrom({ ...base, VAWRA_S3_ENDPOINT: 'https://acct.r2.cloudflarestorage.com' })!.virtualHost).toBe(false);
  });
});

describe('photo storage settings', () => {
  it('are all or nothing, and well formed', () => {
    expect(s3Problems({}, true)).toEqual([]);
    expect(s3Problems({ VAWRA_S3_BUCKET: 'b' }, false).join()).toMatch(/needs all of/);
    const full = {
      VAWRA_S3_ENDPOINT: 'http://minio.local:9000',
      VAWRA_S3_BUCKET: 'vawra-photos',
      VAWRA_S3_REGION: 'auto',
      VAWRA_S3_ACCESS_KEY_ID: 'K',
      VAWRA_S3_SECRET_ACCESS_KEY: 'S',
    };
    expect(s3Problems(full, false)).toEqual([]);
    expect(s3Problems(full, true).join()).toMatch(/https:\/\/ in production/);
    expect(s3Problems({ ...full, VAWRA_S3_BUCKET: 'Bad_Bucket' }, false).join()).toMatch(/bucket name/);
    expect(s3Problems({ ...full, VAWRA_S3_PREFIX: 'photos' }, false).join()).toMatch(/ends with a slash/);
  });
});

describe('the running server with an object store', () => {
  let s3server: Server | undefined;
  afterEach(async () => {
    await new Promise<void>((resolve) => (s3server ? s3server.close(() => resolve()) : resolve()));
    s3server = undefined;
  });

  it('keeps an uploaded photo in the store, not on the server', async () => {
    const { randomBytes, createHash, randomUUID } = await import('node:crypto');
    const { existsSync, mkdtempSync, readdirSync, rmSync } = await import('node:fs');
    const { tmpdir } = await import('node:os');
    const { join } = await import('node:path');
    const sharp = (await import('sharp')).default;
    const { loadConfig } = await import('../src/config.js');
    const { startServer } = await import('../src/start.js');
    const { member } = await import('./harness.js');

    const stored: string[] = [];
    s3server = createServer((req, res) => {
      req.resume();
      req.on('end', () => {
        if (req.method === 'PUT') stored.push(req.url!);
        res.end();
      });
    });
    await new Promise<void>((resolve) => s3server!.listen(0, '127.0.0.1', () => resolve()));
    const env = {
      VAWRA_DATA_KEY: randomBytes(32).toString('base64'),
      VAWRA_LOOKUP_KEY: randomBytes(32).toString('base64'),
      VAWRA_S3_ENDPOINT: `http://127.0.0.1:${(s3server.address() as AddressInfo).port}`,
      VAWRA_S3_BUCKET: 'vawra-photos',
      VAWRA_S3_REGION: 'auto',
      VAWRA_S3_ACCESS_KEY_ID: 'KEY',
      VAWRA_S3_SECRET_ACCESS_KEY: 'SECRET',
      VAWRA_S3_PREFIX: 'photos/',
    };
    const dir = mkdtempSync(join(tmpdir(), 'vawra-s3-'));
    const outbox: { email: string; proof: string; purpose: string }[] = [];
    const running = await startServer({ ...loadConfig(env), port: 0, dataDir: undefined, mediaDir: join(dir, 'media') }, env, {
      logger: false,
      delivery: { sendProof: async (email, proof, purpose) => void outbox.push({ email, proof, purpose }) },
    });
    try {
      const h = { app: running.app, db: running.db, outbox } as never;
      const ana = await member(h, 'Ana');
      const bytes = await sharp({ create: { width: 64, height: 64, channels: 3, background: '#88aacc' } }).jpeg().toBuffer();
      const grant = (
        await running.app.inject({
          method: 'POST',
          url: '/v1/me/photos',
          headers: ana.auth,
          payload: {
            client_upload_id: randomUUID(),
            mime_type: 'image/jpeg',
            byte_length: bytes.length,
            sha256: createHash('sha256').update(bytes).digest('hex'),
          },
        })
      ).json();
      const upload = await running.app.inject({
        method: 'PUT',
        url: grant.upload_url,
        headers: { 'content-type': 'image/jpeg' },
        payload: bytes,
      });
      expect(upload.statusCode).toBe(200);
      expect(stored).toEqual([`/vawra-photos/photos/${grant.photo_id}.webp`]);
      // Nothing on the server's disk: the local photo folder is never even created.
      expect(existsSync(join(dir, 'media')) ? readdirSync(join(dir, 'media')) : []).toEqual([]);
    } finally {
      await running.close();
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
