import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { env } from '../config/env.js';
import { CatalogTrack } from '../data/catalog.js';
import { dbStore } from '../db/store.js';
import { storageService } from '../services/storage.js';

const createPlaylistSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(400).nullable().optional(),
  coverUrl: z.string().url().nullable().optional(),
  isPublic: z.boolean().optional(),
  trackIds: z.array(z.string()).optional(),
});

const updatePlaylistSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  description: z.string().max(400).nullable().optional(),
  coverUrl: z.string().url().nullable().optional(),
  isPublic: z.boolean().optional(),
});

const addTrackSchema = z.object({
  trackId: z.string().min(1),
  trackMetadata: z.record(z.unknown()).optional(),
});

const reorderSchema = z.object({
  orderedTrackIds: z.array(z.string().min(1)),
});

const coverBase64Schema = z.object({
  imageBase64: z.string().min(16),
  mimeType: z.string().default('image/jpeg'),
});

export async function playlistRoutes(app: FastifyInstance): Promise<void> {
  // List current user's playlists (or demo user's public playlists for guest browsing)
  app.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    let userId = 'usr_anni_demo_001';
    try {
      await request.jwtVerify();
      userId = (request.user as { sub: string }).sub;
    } catch {
      // Guest fallback to curated demo playlists
    }
    const playlists = dbStore.getPlaylistsForUser(userId);
    return reply.send({ playlists });
  });

  // Create new playlist
  app.post(
    '/',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const body = createPlaylistSchema.parse(request.body);
      const playlist = dbStore.createPlaylist({
        userId,
        ...body,
      });
      return reply.status(201).send({
        playlist,
        shareUrl: `${env.PUBLIC_BASE_URL}/api/v1/playlists/share/${playlist.shareSlug}`,
      });
    }
  );

  // Get playlist by ID
  app.get('/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const playlist = dbStore.getPlaylistById(id);
    if (!playlist) {
      return reply.status(404).send({ error: 'Not Found', message: 'Playlist not found.' });
    }
    return reply.send({
      playlist,
      shareUrl: `${env.PUBLIC_BASE_URL}/api/v1/playlists/share/${playlist.shareSlug}`,
    });
  });

  // Update playlist metadata
  app.patch(
    '/:id',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const { id } = request.params as { id: string };
      const body = updatePlaylistSchema.parse(request.body);
      const updated = dbStore.updatePlaylist(id, userId, body);
      if (!updated) {
        return reply
          .status(404)
          .send({ error: 'Not Found', message: 'Playlist not found or unauthorized.' });
      }
      return reply.send({ playlist: updated });
    }
  );

  // Delete playlist
  app.delete(
    '/:id',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const { id } = request.params as { id: string };
      const ok = dbStore.deletePlaylist(id, userId);
      if (!ok) {
        return reply
          .status(404)
          .send({ error: 'Not Found', message: 'Playlist not found or unauthorized.' });
      }
      return reply.send({ success: true });
    }
  );

  // Add track to playlist
  app.post(
    '/:id/tracks',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const { id } = request.params as { id: string };
      const body = addTrackSchema.parse(request.body);
      const updated = dbStore.addTrackToPlaylist(
        id,
        userId,
        body.trackId,
        body.trackMetadata as unknown as CatalogTrack | undefined
      );
      if (!updated) {
        return reply
          .status(404)
          .send({ error: 'Not Found', message: 'Playlist not found or unauthorized.' });
      }
      return reply.send({ playlist: updated });
    }
  );

  // Remove track from playlist
  app.delete(
    '/:id/tracks/:trackId',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const { id, trackId } = request.params as { id: string; trackId: string };
      const updated = dbStore.removeTrackFromPlaylist(id, userId, trackId);
      if (!updated) {
        return reply
          .status(404)
          .send({ error: 'Not Found', message: 'Playlist not found or unauthorized.' });
      }
      return reply.send({ playlist: updated });
    }
  );

  // Reorder tracks in playlist
  app.put(
    '/:id/reorder',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const { id } = request.params as { id: string };
      const body = reorderSchema.parse(request.body);
      const updated = dbStore.reorderPlaylistTracks(id, userId, body.orderedTrackIds);
      if (!updated) {
        return reply
          .status(404)
          .send({ error: 'Not Found', message: 'Playlist not found or unauthorized.' });
      }
      return reply.send({ playlist: updated });
    }
  );

  // Upload custom cover artwork (Multipart OR Base64 JSON to S3/R2/MinIO)
  app.post(
    '/:id/cover',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const { id } = request.params as { id: string };

      let buffer: Buffer;
      let mimeType = 'image/jpeg';

      if (request.isMultipart()) {
        const part = await request.file();
        if (!part) {
          return reply.status(400).send({ error: 'Bad Request', message: 'Missing cover file.' });
        }
        buffer = await part.toBuffer();
        mimeType = part.mimetype || 'image/jpeg';
      } else {
        const parsed = coverBase64Schema.parse(request.body);
        const cleanBase64 = parsed.imageBase64.replace(/^data:image\/\w+;base64,/, '');
        buffer = Buffer.from(cleanBase64, 'base64');
        mimeType = parsed.mimeType;
      }

      const uploaded = await storageService.uploadArtwork(buffer, mimeType, `playlists/${id}`);
      const updated = dbStore.updatePlaylist(id, userId, { coverUrl: uploaded.url });
      if (!updated) {
        return reply
          .status(404)
          .send({ error: 'Not Found', message: 'Playlist not found or unauthorized.' });
      }

      return reply.send({
        coverUrl: uploaded.url,
        storageProvider: uploaded.storageProvider,
        playlist: updated,
      });
    }
  );

  // Public share link resolution
  app.get('/share/:shareSlug', async (request: FastifyRequest, reply: FastifyReply) => {
    const { shareSlug } = request.params as { shareSlug: string };
    const playlist = dbStore.getPlaylistByShareSlug(shareSlug);
    if (!playlist) {
      return reply
        .status(404)
        .send({ error: 'Not Found', message: 'Shared playlist not found or is private.' });
    }
    return reply.send({ playlist });
  });

  // Export playlist as standard M3U8 file
  app.get('/:id/export.m3u', async (request: FastifyRequest, reply: FastifyReply) => {
    const { id } = request.params as { id: string };
    const playlist = dbStore.getPlaylistById(id);
    if (!playlist) {
      return reply.status(404).send({ error: 'Not Found', message: 'Playlist not found.' });
    }

    const lines = ['#EXTM3U', `#PLAYLIST:${playlist.name}`];
    for (const track of playlist.resolvedTracks) {
      lines.push(`#EXTINF:${track.durationSeconds},${track.artist} - ${track.title}`);
      lines.push(track.streamUrl ?? `anni://track/${track.id}`);
    }

    reply.header('Content-Type', 'audio/x-mpegurl; charset=utf-8');
    reply.header('Content-Disposition', `attachment; filename="${playlist.shareSlug}.m3u8"`);
    return reply.send(lines.join('\n'));
  });
}
