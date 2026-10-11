import { env } from '../config/env.js';
import { CatalogTrack, INITIAL_LEGAL_CATALOG } from '../data/catalog.js';
import { MusicSourceProvider } from './music-provider.interface.js';

interface YouTubeSearchItem {
  id?: { videoId?: string };
  snippet?: {
    title?: string;
    channelTitle?: string;
    publishedAt?: string;
    thumbnails?: {
      high?: { url?: string };
      medium?: { url?: string };
    };
  };
}

/**
 * Official YouTube Data API v3 search & metadata provider.
 * Strictly adheres to YouTube API Terms of Service:
 * - Returns metadata and `youtubeVideoId` for playback exclusively in the official YouTube IFrame Player.
 * - Never extracts, proxies, or rips raw audio streams (`streamUrl: null`).
 * - Never provides audio downloads (`supportsLegalDownload = false`, `resolveDownloadUrl` returns `null`).
 */
export class YouTubeProvider implements MusicSourceProvider {
  readonly sourceName = 'youtube' as const;
  readonly supportsDirectStream = false;
  readonly supportsLegalDownload = false;

  async searchTracks(query: string, limit = 8): Promise<CatalogTrack[]> {
    const q = query.trim().toLowerCase();
    const localMatches = INITIAL_LEGAL_CATALOG.filter(
      (t) =>
        t.source === 'youtube' &&
        (t.title.toLowerCase().includes(q) ||
          t.artist.toLowerCase().includes(q) ||
          t.genre.toLowerCase().includes(q))
    );

    if (env.YOUTUBE_API_KEY && env.NODE_ENV !== 'test') {
      try {
        const url = new URL('https://www.googleapis.com/youtube/v3/search');
        url.searchParams.set('part', 'snippet');
        url.searchParams.set('type', 'video');
        url.searchParams.set('videoCategoryId', '10'); // Music category
        url.searchParams.set('videoEmbeddable', 'true');
        url.searchParams.set('maxResults', String(limit));
        url.searchParams.set('q', query);
        url.searchParams.set('key', env.YOUTUBE_API_KEY);

        const res = await fetch(url.toString(), { signal: AbortSignal.timeout(3500) });
        if (res.ok) {
          const data = (await res.json()) as { items?: YouTubeSearchItem[] };
          const items = data.items ?? [];
          const mapped: CatalogTrack[] = items
            .filter((item) => Boolean(item.id?.videoId))
            .map((item) => {
              const videoId = item.id!.videoId!;
              return {
                id: `youtube_${videoId}`,
                source: 'youtube',
                externalId: videoId,
                youtubeVideoId: videoId,
                title: item.snippet?.title || 'YouTube Music Video',
                artist: item.snippet?.channelTitle || 'YouTube Artist',
                album: 'YouTube Official IFrame Stream',
                genre: 'Pop',
                durationSeconds: 210,
                artworkUrl:
                  item.snippet?.thumbnails?.high?.url ||
                  `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
                streamUrl: null, // Official IFrame player only
                downloadUrl: null, // Downloads strictly prohibited for YouTube
                qualityBadge: 'YT-HD',
                license: 'YouTube Standard License (Official IFrame Playback Only)',
                releaseYear: item.snippet?.publishedAt
                  ? Number(item.snippet.publishedAt.slice(0, 4))
                  : 2025,
                waveform: [0.35, 0.62, 0.78, 0.51, 0.89, 0.64, 0.72, 0.48],
                dominantColor: '#EC4899',
              };
            });

          if (mapped.length > 0) {
            return mapped;
          }
        }
      } catch {
        // Fallback to seeded official YouTube embed tracks
      }
    }

    return localMatches.length > 0
      ? localMatches.slice(0, limit)
      : INITIAL_LEGAL_CATALOG.filter((t) => t.source === 'youtube').slice(0, limit);
  }

  async getTrending(limit = 5): Promise<CatalogTrack[]> {
    return INITIAL_LEGAL_CATALOG.filter((t) => t.source === 'youtube').slice(0, limit);
  }

  async getTrackById(id: string): Promise<CatalogTrack | null> {
    const cleanId = id.replace(/^youtube_/, '');
    const existing = INITIAL_LEGAL_CATALOG.find(
      (t) => t.source === 'youtube' && (t.id === id || t.externalId === cleanId)
    );
    if (existing) return existing;

    return {
      id: `youtube_${cleanId}`,
      source: 'youtube',
      externalId: cleanId,
      youtubeVideoId: cleanId,
      title: `YouTube Official Track (${cleanId})`,
      artist: 'YouTube Official Channel',
      album: 'YouTube IFrame Stream',
      genre: 'Electronic',
      durationSeconds: 210,
      artworkUrl: `https://i.ytimg.com/vi/${cleanId}/hqdefault.jpg`,
      streamUrl: null,
      downloadUrl: null,
      qualityBadge: 'YT-HD',
      license: 'YouTube Standard License (Official IFrame Playback Only)',
      releaseYear: 2025,
      waveform: [0.3, 0.6, 0.8, 0.5, 0.7, 0.9, 0.4, 0.65],
      dominantColor: '#EC4899',
    };
  }

  async resolveDownloadUrl(): Promise<null> {
    // Strictly prohibited by YouTube Terms of Service
    return null;
  }
}
