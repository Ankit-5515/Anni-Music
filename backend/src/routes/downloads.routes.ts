import crypto from 'node:crypto';
import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { env } from '../config/env.js';
import { dbStore } from '../db/store.js';
import { providerRegistry } from '../providers/provider-registry.js';

const signDownloadSchema = z.object({
  trackId: z.string().min(1),
  preferredQuality: z.enum(['FLAC', '320kbps']).default('FLAC'),
});

export async function downloadRoutes(app: FastifyInstance): Promise<void> {
  const createSignedDownloadResponse = async (
    trackId: string,
    preferredQuality: 'FLAC' | '320kbps',
    reply: FastifyReply
  ) => {
    const track = dbStore.getTrackById(trackId);
    if (!track) {
      return reply.status(404).send({
        error: 'Not Found',
        message: `Track '${trackId}' not found.`,
      });
    }

    if (track.source === 'youtube') {
      return reply.status(403).send({
        error: 'Forbidden',
        message:
          'YouTube tracks use the official YouTube IFrame Player for streaming only and cannot be downloaded per YouTube Terms of Service.',
      });
    }

    const provider = providerRegistry.getProvider(
      track.source === 'internet_archive' ? 'internet_archive' : 'jamendo'
    );
    const resolved = provider
      ? await provider.resolveDownloadUrl(track.externalId, preferredQuality)
      : null;

    const directUrl =
      resolved?.downloadUrl ||
      track.downloadUrl ||
      track.streamUrl ||
      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

    const expiresAt = Math.floor(Date.now() / 1000) + 3600; // 1 hour validity
    const payload = `${track.id}:${preferredQuality}:${expiresAt}`;
    const signature = crypto
      .createHmac('sha256', env.DOWNLOAD_SIGNING_SECRET)
      .update(payload)
      .digest('hex');

    const signedUrl = `${env.PUBLIC_BASE_URL}/api/v1/downloads/stream/${encodeURIComponent(
      track.id
    )}?quality=${preferredQuality}&expires=${expiresAt}&sig=${signature}`;

    return reply.send({
      trackId: track.id,
      title: track.title,
      artist: track.artist,
      source: track.source,
      qualityBadge: resolved?.qualityBadge ?? preferredQuality,
      license: resolved?.license ?? track.license,
      directDownloadUrl: directUrl,
      signedUrl,
      expiresAt: new Date(expiresAt * 1000).toISOString(),
    });
  };

  // POST /api/v1/downloads/sign
  app.post('/sign', async (request: FastifyRequest, reply: FastifyReply) => {
    const body = signDownloadSchema.parse(request.body);
    return createSignedDownloadResponse(body.trackId, body.preferredQuality, reply);
  });

  // GET /api/v1/downloads/:trackId/manifest (OpenAPI alias)
  app.get('/:trackId/manifest', async (request: FastifyRequest, reply: FastifyReply) => {
    const { trackId } = request.params as { trackId: string };
    const { quality } = (request.query as { quality?: 'FLAC' | '320kbps' }) ?? {};
    return createSignedDownloadResponse(trackId, quality ?? 'FLAC', reply);
  });

  // GET /api/v1/downloads/stream/:trackId — Verifies HMAC signature and redirects to legal audio file
  app.get('/stream/:trackId', async (request: FastifyRequest, reply: FastifyReply) => {
    const { trackId } = request.params as { trackId: string };
    const {
      quality = 'FLAC',
      expires,
      sig,
    } = request.query as {
      quality?: string;
      expires?: string;
      sig?: string;
    };

    if (!expires || !sig) {
      return reply.status(400).send({ error: 'Bad Request', message: 'Missing signature parameters.' });
    }

    if (Number(expires) < Math.floor(Date.now() / 1000)) {
      return reply.status(410).send({ error: 'Gone', message: 'Signed download link has expired.' });
    }

    const expectedSig = crypto
      .createHmac('sha256', env.DOWNLOAD_SIGNING_SECRET)
      .update(`${trackId}:${quality}:${expires}`)
      .digest('hex');

    if (expectedSig !== sig) {
      return reply.status(403).send({ error: 'Forbidden', message: 'Invalid download signature.' });
    }

    const track = dbStore.getTrackById(trackId);
    if (!track || track.source === 'youtube' || !track.downloadUrl) {
      return reply.status(404).send({ error: 'Not Found', message: 'Downloadable asset not found.' });
    }

    return reply.redirect(302, track.downloadUrl);
  });
}
