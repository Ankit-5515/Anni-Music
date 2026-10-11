import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { env } from '../config/env.js';

export class ObjectStorageService {
  private s3: S3Client;
  private localUploadsDir: string;

  constructor() {
    this.s3 = new S3Client({
      region: env.S3_REGION,
      endpoint: env.S3_ENDPOINT,
      forcePathStyle: true,
      credentials: {
        accessKeyId: env.S3_ACCESS_KEY_ID,
        secretAccessKey: env.S3_SECRET_ACCESS_KEY,
      },
    });
    this.localUploadsDir = path.resolve(process.cwd(), 'data', 'uploads');
  }

  async uploadArtwork(
    buffer: Buffer,
    mimeType: string,
    prefix = 'covers'
  ): Promise<{ key: string; url: string; storageProvider: 's3' | 'local' }> {
    const ext = mimeType.includes('png') ? 'png' : mimeType.includes('webp') ? 'webp' : 'jpg';
    const key = `${prefix}/${Date.now()}-${crypto.randomBytes(6).toString('hex')}.${ext}`;

    try {
      await this.s3.send(
        new PutObjectCommand({
          Bucket: env.S3_BUCKET,
          Key: key,
          Body: buffer,
          ContentType: mimeType,
        })
      );
      return {
        key,
        url: `${env.S3_PUBLIC_URL.replace(/\/$/, '')}/${key}`,
        storageProvider: 's3',
      };
    } catch {
      // Fallback to local persistent storage when S3/MinIO is not reachable
      const targetPath = path.join(this.localUploadsDir, key);
      await fs.mkdir(path.dirname(targetPath), { recursive: true });
      await fs.writeFile(targetPath, buffer);
      return {
        key,
        url: `${env.PUBLIC_BASE_URL.replace(/\/$/, '')}/api/v1/playlists/assets/${key}`,
        storageProvider: 'local',
      };
    }
  }

  async getPresignedDownloadUrl(key: string, expiresInSeconds = 3600): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: env.S3_BUCKET,
      Key: key,
    });
    return getSignedUrl(this.s3, command, { expiresIn: expiresInSeconds });
  }

  async readLocalAsset(key: string): Promise<Buffer | null> {
    const safeKey = key.replace(/\.\./g, '');
    const fullPath = path.join(this.localUploadsDir, safeKey);
    try {
      return await fs.readFile(fullPath);
    } catch {
      return null;
    }
  }
}

export const storageService = new ObjectStorageService();
