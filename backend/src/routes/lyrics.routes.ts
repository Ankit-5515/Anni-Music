import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { env } from '../config/env.js';
import { dbStore } from '../db/store.js';

const lyricsQuerySchema = z.object({
  trackId: z.string().optional(),
  title: z.string().optional(),
  artist: z.string().optional(),
});

function buildDefaultSyncedLrc(title: string, artist: string): string {
  return `[00:00.00] ♪ ${title} — ${artist} ♪
[00:08.50] Drifting through the frequencies of sound and light
[00:16.20] Every note awakens in the velvet night
[00:24.80] ${title} echoing across the skyline glow
[00:33.40] Where the rhythm takes us is the place we know
[00:42.00] Close your eyes and let the stereo horizon breathe
[00:51.60] Pure harmonics rising from the deep beneath
[01:02.00] ♪ Instrumental Interlude ♪
[01:18.50] Your music, your world, spinning in the dark
[01:28.00] Every single frequency leaves a timeless mark`;
}

export async function lyricsRoutes(app: FastifyInstance): Promise<void> {
  const resolveLyrics = async (trackId?: string, titleParam?: string, artistParam?: string) => {
    let title = titleParam ?? '';
    let artist = artistParam ?? '';

    if (trackId) {
      const track = dbStore.getTrackById(trackId);
      if (track) {
        title = track.title;
        artist = track.artist;
        if (track.syncedLrc) {
          return {
            trackId: track.id,
            title: track.title,
            artist: track.artist,
            syncedLrc: track.syncedLrc,
            plainLyrics: track.syncedLrc.replace(/\[\d{2}:\d{2}\.\d{2}\]\s*/g, ''),
            source: 'anni-catalog',
          };
        }
      }
    }

    if (!title) title = 'Anni Music Track';
    if (!artist) artist = 'Anni Artist';

    const cached = dbStore.getLyrics(artist, title);
    if (cached) {
      return {
        trackId: trackId ?? null,
        title: cached.title,
        artist: cached.artist,
        syncedLrc: cached.syncedLrc,
        plainLyrics: cached.plainLyrics,
        source: cached.source,
      };
    }

    // Attempt live lookup from open LRCLIB API when not in test mode
    if (env.NODE_ENV !== 'test') {
      try {
        const url = new URL(`${env.LRCLIB_BASE_URL}/get`);
        url.searchParams.set('artist_name', artist);
        url.searchParams.set('track_name', title);

        const res = await fetch(url.toString(), { signal: AbortSignal.timeout(3000) });
        if (res.ok) {
          const data = (await res.json()) as {
            syncedLyrics?: string;
            plainLyrics?: string;
          };
          if (data.syncedLyrics || data.plainLyrics) {
            const synced = data.syncedLyrics || buildDefaultSyncedLrc(title, artist);
            const plain = data.plainLyrics || synced.replace(/\[\d{2}:\d{2}\.\d{2}\]\s*/g, '');
            dbStore.saveLyrics({
              trackKey: `${artist.toLowerCase().trim()}::${title.toLowerCase().trim()}`,
              title,
              artist,
              syncedLrc: synced,
              plainLyrics: plain,
              source: 'lrclib.net',
              updatedAt: new Date().toISOString(),
            });
            return {
              trackId: trackId ?? null,
              title,
              artist,
              syncedLrc: synced,
              plainLyrics: plain,
              source: 'lrclib.net',
            };
          }
        }
      } catch {
        // Fallback to generated LRC
      }
    }

    const fallbackLrc = buildDefaultSyncedLrc(title, artist);
    const plain = fallbackLrc.replace(/\[\d{2}:\d{2}\.\d{2}\]\s*/g, '');
    return {
      trackId: trackId ?? null,
      title,
      artist,
      syncedLrc: fallbackLrc,
      plainLyrics: plain,
      source: 'anni-synced-generator',
    };
  };

  app.get('/', async (request: FastifyRequest, reply: FastifyReply) => {
    const query = lyricsQuerySchema.parse(request.query);
    const result = await resolveLyrics(query.trackId, query.title, query.artist);
    return reply.send(result);
  });

  app.get('/:trackId', async (request: FastifyRequest, reply: FastifyReply) => {
    const { trackId } = request.params as { trackId: string };
    const result = await resolveLyrics(trackId);
    return reply.send(result);
  });
}
