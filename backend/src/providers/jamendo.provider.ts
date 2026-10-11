import { env } from '../config/env.js';
import { CatalogTrack, INITIAL_LEGAL_CATALOG } from '../data/catalog.js';
import { MusicSourceProvider } from './music-provider.interface.js';

interface JamendoApiTrack {
  id: string;
  name: string;
  duration: number;
  artist_name: string;
  album_name: string;
  releasedate?: string;
  album_image?: string;
  image?: string;
  audio?: string;
  audiodownload?: string;
  audiodownload_allowed?: boolean;
  license_ccurl?: string;
  musicinfo?: {
    tags?: {
      genres?: string[];
    };
  };
}

export class JamendoProvider implements MusicSourceProvider {
  readonly sourceName = 'jamendo' as const;
  readonly supportsDirectStream = true;
  readonly supportsLegalDownload = true;

  private mapJamendoTrack(raw: JamendoApiTrack): CatalogTrack {
    const genre = raw.musicinfo?.tags?.genres?.[0] || 'Electronic';
    const year = raw.releasedate ? Number(raw.releasedate.slice(0, 4)) || 2025 : 2025;
    return {
      id: `jamendo_${raw.id}`,
      source: 'jamendo',
      externalId: String(raw.id),
      title: raw.name,
      artist: raw.artist_name || 'Jamendo Artist',
      album: raw.album_name || 'Jamendo Sessions',
      genre: genre.charAt(0).toUpperCase() + genre.slice(1),
      durationSeconds: Number(raw.duration) || 200,
      artworkUrl:
        raw.album_image ||
        raw.image ||
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
      streamUrl: raw.audio || null,
      downloadUrl: raw.audiodownload_allowed !== false ? raw.audiodownload || raw.audio || null : null,
      qualityBadge: 'FLAC',
      license: raw.license_ccurl || 'CC BY-NC-SA 4.0 (Jamendo)',
      releaseYear: year,
      waveform: [0.25, 0.48, 0.72, 0.61, 0.85, 0.54, 0.91, 0.44, 0.68, 0.79, 0.52, 0.36],
      dominantColor: '#8B5CF6',
    };
  }

  async searchTracks(query: string, limit = 10): Promise<CatalogTrack[]> {
    const q = query.trim().toLowerCase();
    const localMatches = INITIAL_LEGAL_CATALOG.filter(
      (t) =>
        t.source === 'jamendo' &&
        (t.title.toLowerCase().includes(q) ||
          t.artist.toLowerCase().includes(q) ||
          t.genre.toLowerCase().includes(q) ||
          t.album.toLowerCase().includes(q))
    );

    if (env.NODE_ENV === 'test') {
      return localMatches.slice(0, limit);
    }

    try {
      const url = new URL('https://api.jamendo.com/v3.0/tracks/');
      url.searchParams.set('client_id', env.JAMENDO_CLIENT_ID);
      url.searchParams.set('format', 'json');
      url.searchParams.set('limit', String(limit));
      url.searchParams.set('namesearch', query);
      url.searchParams.set('include', 'musicinfo');
      url.searchParams.set('audioformat', 'flac');

      const response = await fetch(url.toString(), { signal: AbortSignal.timeout(3500) });
      if (response.ok) {
        const body = (await response.json()) as { results?: JamendoApiTrack[] };
        if (body.results && body.results.length > 0) {
          const remote = body.results.map((r) => this.mapJamendoTrack(r));
          const merged = [...localMatches, ...remote];
          const seen = new Set<string>();
          return merged.filter((item) => {
            if (seen.has(item.id)) return false;
            seen.add(item.id);
            return true;
          }).slice(0, limit);
        }
      }
    } catch {
      // Fallback to curated Jamendo catalog when offline or rate-limited
    }

    return localMatches.length > 0
      ? localMatches.slice(0, limit)
      : INITIAL_LEGAL_CATALOG.filter((t) => t.source === 'jamendo').slice(0, limit);
  }

  async getTrending(limit = 8): Promise<CatalogTrack[]> {
    return INITIAL_LEGAL_CATALOG.filter((t) => t.source === 'jamendo').slice(0, limit);
  }

  async getTrackById(id: string): Promise<CatalogTrack | null> {
    const cleanId = id.startsWith('jamendo_') ? id : `jamendo_${id}`;
    const found = INITIAL_LEGAL_CATALOG.find((t) => t.id === cleanId);
    return found ?? null;
  }

  async resolveDownloadUrl(
    externalId: string,
    preferredQuality: 'FLAC' | '320kbps' = 'FLAC'
  ): Promise<{ downloadUrl: string; qualityBadge: 'FLAC' | '320kbps'; license: string } | null> {
    const cleanId = externalId.replace(/^jamendo_/, '');
    const catalogTrack = INITIAL_LEGAL_CATALOG.find(
      (t) => t.source === 'jamendo' && t.externalId === cleanId
    );
    if (catalogTrack && catalogTrack.downloadUrl) {
      return {
        downloadUrl: `${catalogTrack.downloadUrl}?format=${preferredQuality.toLowerCase()}`,
        qualityBadge: preferredQuality,
        license: catalogTrack.license,
      };
    }

    return {
      downloadUrl: `https://prod-1.storage.jamendo.com/download/track/${cleanId}/${preferredQuality === 'FLAC' ? 'flac' : 'mp32'}/`,
      qualityBadge: preferredQuality,
      license: 'CC BY-NC-SA 4.0 (Jamendo Legal Download)',
    };
  }
}
