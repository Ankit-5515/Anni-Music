import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { dbStore } from '../db/store.js';
import { ProviderSource } from '../providers/music-provider.interface.js';
import { providerRegistry } from '../providers/provider-registry.js';

const searchQuerySchema = z.object({
  q: z.string().default(''),
  providers: z.string().optional(), // comma-separated: "jamendo,internet_archive,youtube"
  genre: z.string().optional(),
  limit: z.coerce.number().min(1).max(50).default(12),
});

export async function searchRoutes(app: FastifyInstance): Promise<void> {
  app.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const query = searchQuerySchema.parse(request.query);
    const providerList = query.providers
      ? (query.providers
          .split(',')
          .map((s) => s.trim())
          .filter((s) =>
            ['jamendo', 'internet_archive', 'youtube'].includes(s)
          ) as ProviderSource[])
      : undefined;

    if (!query.q.trim()) {
      let tracks = dbStore.getAllTracks();
      if (providerList && providerList.length > 0) {
        tracks = tracks.filter((t) => providerList.includes(t.source as ProviderSource));
      }
      if (query.genre) {
        tracks = tracks.filter((t) => t.genre.toLowerCase() === query.genre!.toLowerCase());
      }
      return reply.send({
        query: '',
        total: tracks.length,
        results: tracks.slice(0, query.limit),
        byProvider: {
          jamendo: tracks.filter((t) => t.source === 'jamendo'),
          internet_archive: tracks.filter((t) => t.source === 'internet_archive'),
          youtube: tracks.filter((t) => t.source === 'youtube'),
        },
      });
    }

    const unified = await providerRegistry.searchUnified(query.q, providerList, query.limit);
    return reply.send(unified);
  });

  app.get('/trending', async (_request: FastifyRequest, reply: FastifyReply) => {
    const tracks = dbStore.getAllTracks();
    return reply.send({
      tracks,
      updatedAt: new Date().toISOString(),
    });
  });

  app.get('/genres', async (_request: FastifyRequest, reply: FastifyReply) => {
    const genres = [
      { id: 'electronic', name: 'Electronic', color: '#8B5CF6', trackCount: 42 },
      { id: 'synthwave', name: 'Synthwave', color: '#EC4899', trackCount: 28 },
      { id: 'lofi', name: 'Lo-Fi', color: '#F59E0B', trackCount: 35 },
      { id: 'ambient', name: 'Ambient', color: '#06B6D4', trackCount: 19 },
      { id: 'jazz', name: 'Jazz', color: '#D97706', trackCount: 24 },
      { id: 'classical', name: 'Classical', color: '#3B82F6', trackCount: 16 },
      { id: 'hiphop', name: 'Hip-Hop', color: '#EF4444', trackCount: 31 },
      { id: 'indie', name: 'Indie Rock', color: '#10B981', trackCount: 22 },
    ];
    return reply.send({ genres });
  });
}
