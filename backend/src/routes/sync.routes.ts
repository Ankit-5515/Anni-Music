import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { CatalogTrack } from '../data/catalog.js';
import { dbStore } from '../db/store.js';

const syncPushSchema = z.object({
  favoriteTrackIdsToAdd: z.array(z.string()).optional(),
  favoriteTrackIdsToRemove: z.array(z.string()).optional(),
  customTracks: z.array(z.record(z.unknown())).optional(),
  playEvents: z
    .array(
      z.object({
        trackId: z.string(),
        listenedSeconds: z.number().int().nonnegative().optional(),
        completed: z.boolean().optional(),
      })
    )
    .optional(),
  settings: z
    .object({
      themeMode: z.enum(['dark', 'amoled', 'light']).optional(),
      streamingQuality: z.enum(['FLAC', '320kbps', '192kbps']).optional(),
      downloadQuality: z.enum(['FLAC', '320kbps']).optional(),
      crossfadeSeconds: z.number().int().min(0).max(12).optional(),
      gaplessPlayback: z.boolean().optional(),
      replayGain: z.boolean().optional(),
      equalizerEnabled: z.boolean().optional(),
      equalizerPreset: z.string().optional(),
      equalizerBands: z.array(z.number()).length(10).optional(),
      bassBoostStrength: z.number().int().min(0).max(1000).optional(),
      virtualizerStrength: z.number().int().min(0).max(1000).optional(),
      wifiOnlyDownloads: z.boolean().optional(),
    })
    .optional(),
});

export async function syncRoutes(app: FastifyInstance): Promise<void> {
  // Pull complete synced library state for authenticated user
  app.get(
    '/',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      return reply.send({
        syncedAt: new Date().toISOString(),
        favorites: dbStore.getFavorites(userId),
        playlists: dbStore.getPlaylistsForUser(userId),
        playHistory: dbStore.getPlayHistory(userId, 50),
        settings: dbStore.getUserSettings(userId),
      });
    }
  );

  // Push & merge device delta (favorites, play history, settings, local track metadata)
  app.post(
    '/',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const body = syncPushSchema.parse(request.body);

      if (body.customTracks) {
        for (const rawTrack of body.customTracks) {
          if (rawTrack && typeof rawTrack.id === 'string') {
            dbStore.upsertTrack(rawTrack as unknown as CatalogTrack);
          }
        }
      }

      if (body.favoriteTrackIdsToAdd) {
        const currentFavIds = new Set(dbStore.getFavorites(userId).map((t) => t.id));
        for (const trackId of body.favoriteTrackIdsToAdd) {
          if (!currentFavIds.has(trackId)) {
            dbStore.toggleFavorite(userId, trackId);
          }
        }
      }

      if (body.favoriteTrackIdsToRemove) {
        const currentFavIds = new Set(dbStore.getFavorites(userId).map((t) => t.id));
        for (const trackId of body.favoriteTrackIdsToRemove) {
          if (currentFavIds.has(trackId)) {
            dbStore.toggleFavorite(userId, trackId);
          }
        }
      }

      if (body.playEvents) {
        for (const ev of body.playEvents) {
          dbStore.recordPlay({
            userId,
            trackId: ev.trackId,
            listenedSeconds: ev.listenedSeconds,
            completed: ev.completed,
          });
        }
      }

      if (body.settings) {
        dbStore.updateUserSettings(userId, body.settings);
      }

      return reply.send({
        syncedAt: new Date().toISOString(),
        favorites: dbStore.getFavorites(userId),
        playlists: dbStore.getPlaylistsForUser(userId),
        playHistory: dbStore.getPlayHistory(userId, 50),
        settings: dbStore.getUserSettings(userId),
      });
    }
  );

  // Convenience endpoint to toggle a single favorite
  app.post(
    '/favorites/toggle',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request.user as { sub: string }).sub;
      const schema = z.object({
        trackId: z.string().min(1),
        trackMetadata: z.record(z.unknown()).optional(),
      });
      const body = schema.parse(request.body);
      const res = dbStore.toggleFavorite(
        userId,
        body.trackId,
        body.trackMetadata as unknown as CatalogTrack | undefined
      );
      return reply.send(res);
    }
  );
}
