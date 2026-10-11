import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(4000),
  HOST: z.string().default('0.0.0.0'),
  PUBLIC_BASE_URL: z.string().default('http://localhost:4000'),
  DATABASE_URL: z
    .string()
    .default('postgresql://anni:anni_secret_password@localhost:5432/anni_music?schema=public'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  JWT_ACCESS_SECRET: z
    .string()
    .min(16)
    .default('anni-music-super-secret-access-key-change-in-prod-2026'),
  JWT_REFRESH_SECRET: z
    .string()
    .min(16)
    .default('anni-music-super-secret-refresh-key-change-in-prod-2026'),
  JWT_ACCESS_EXPIRES_IN: z.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('30d'),
  DOWNLOAD_SIGNING_SECRET: z
    .string()
    .min(16)
    .default('anni-music-signed-download-hmac-secret-2026'),
  GOOGLE_CLIENT_ID: z.string().default('anni-music-google-client-id.apps.googleusercontent.com'),
  S3_ENDPOINT: z.string().default('http://localhost:9000'),
  S3_REGION: z.string().default('auto'),
  S3_BUCKET: z.string().default('anni-music-assets'),
  S3_ACCESS_KEY_ID: z.string().default('minioadmin'),
  S3_SECRET_ACCESS_KEY: z.string().default('minioadmin'),
  S3_PUBLIC_URL: z.string().default('http://localhost:9000/anni-music-assets'),
  JAMENDO_CLIENT_ID: z.string().default('56d30c95'),
  YOUTUBE_API_KEY: z.string().default(''),
  LRCLIB_BASE_URL: z.string().default('https://lrclib.net/api'),
});

export const env = envSchema.parse(process.env);
export type Env = z.infer<typeof envSchema>;
