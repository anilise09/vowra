import { createHmac, timingSafeEqual } from 'node:crypto';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';

/**
 * Where processed photos live. Only derived images are stored: the uploaded
 * original (with its metadata) is never kept. A reviewed object store replaces
 * the disk store in production.
 */
export interface MediaStore {
  put(id: string, bytes: Buffer): Promise<void>;
  get(id: string): Promise<Buffer | null>;
  delete(id: string): Promise<void>;
}

const safeId = (id: string) => {
  if (!/^[0-9a-f-]{36}$/.test(id)) throw new Error('bad media id');
  return id;
};

export class DiskMediaStore implements MediaStore {
  constructor(private readonly dir: string) {
    mkdirSync(dir, { recursive: true });
  }

  async put(id: string, bytes: Buffer) {
    writeFileSync(join(this.dir, `${safeId(id)}.webp`), bytes);
  }

  async get(id: string) {
    try {
      return readFileSync(join(this.dir, `${safeId(id)}.webp`));
    } catch {
      return null;
    }
  }

  async delete(id: string) {
    rmSync(join(this.dir, `${safeId(id)}.webp`), { force: true });
  }
}

export class MemoryMediaStore implements MediaStore {
  readonly files = new Map<string, Buffer>();
  async put(id: string, bytes: Buffer) {
    this.files.set(id, bytes);
  }
  async get(id: string) {
    return this.files.get(id) ?? null;
  }
  async delete(id: string) {
    this.files.delete(id);
  }
}

export const photoRules = {
  maxPhotos: 6,
  maxBytes: 10 * 1024 * 1024,
  /** Refuses decompression bombs before decoding. */
  maxInputPixels: 40_000_000,
  maxSide: 1600,
  uploadsPerDay: 30,
  uploadGrantSeconds: 10 * 60,
  readGrantSeconds: 15 * 60,
  mimeTypes: ['image/jpeg', 'image/png', 'image/webp'] as const,
};

export const rejectReasons = ['nudity', 'not_a_person', 'someone_else', 'contact_info', 'other'] as const;

/** The first bytes of each accepted format; the declared type must match. */
export function sniffMime(bytes: Buffer): string | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'image/png';
  }
  if (bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') {
    return 'image/webp';
  }
  return null;
}

/**
 * Decodes safely and re-encodes: applies the orientation, drops every piece
 * of metadata (GPS, camera, dates), caps the size, and outputs WebP. A file
 * that is not really an image, or a polyglot, does not survive this.
 */
export async function processPhoto(bytes: Buffer) {
  const { data, info } = await sharp(bytes, {
    limitInputPixels: photoRules.maxInputPixels,
    failOn: 'error',
    animated: false,
  })
    .rotate()
    .resize({
      width: photoRules.maxSide,
      height: photoRules.maxSide,
      fit: 'inside',
      withoutEnlargement: true,
    })
    .webp({ quality: 82 })
    .toBuffer({ resolveWithObject: true });
  return { bytes: data, width: info.width, height: info.height };
}

/** Signs short-lived links for one photo, one viewer and one purpose. */
export class MediaGrants {
  private readonly key: Buffer;

  constructor(dataKey: Buffer) {
    this.key = createHmac('sha256', dataKey).update('vawra-media-grants-v1').digest();
  }

  private sign(purpose: string, id: string, viewer: string, exp: number) {
    return createHmac('sha256', this.key).update(`${purpose}.${id}.${viewer}.${exp}`).digest('base64url');
  }

  url(purpose: 'view' | 'review', id: string, viewer: string, now: Date): string {
    const exp = Math.floor(now.getTime() / 1000) + photoRules.readGrantSeconds;
    return `/v1/media/${id}?p=${purpose}&v=${viewer}&e=${exp}&s=${this.sign(purpose, id, viewer, exp)}`;
  }

  check(purpose: string, id: string, viewer: string, exp: number, sig: string, now: Date): boolean {
    if (!Number.isFinite(exp) || exp * 1000 < now.getTime()) return false;
    const expected = Buffer.from(this.sign(purpose, id, viewer, exp));
    const given = Buffer.from(sig);
    return expected.length === given.length && timingSafeEqual(expected, given);
  }
}
