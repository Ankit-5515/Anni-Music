import { env } from '../config/env.js';
import { CatalogTrack, INITIAL_LEGAL_CATALOG } from '../data/catalog.js';
import { MusicSourceProvider } from './music-provider.interface.js';

interface ArchiveSearchDoc {
  identifier: string;
  title?: string;
  creator?: string | string[];
  year?: string | number;
  licenseurl?: string;
}

export class InternetArchiveProvider implements MusicSourceProvider {
  readonly sourceName = 'internet_archive' as const;
  readonly supportsDirectStream = true;
  readonly supportsLegalDownload = true;

  async searchTracks(query: string, limit = 10): Promise<CatalogTrack[]> {
    const q = query.trim().toLowerCase();
    const localMatches = INITIAL_LEGAL_CATALOG.filter(
      (t) =>
        t.source === 'internet_archive' &&
        (t.title.toLowerCase().includes(q) ||
          t.artist.toLowerCase().includes(q) ||
          t.genre.toLowerCase().includes(q) ||
          t.album.toLowerCase().includes(q))
    );

    if (env.NODE_ENV === 'test') {
      return localMatches.slice(0, limit);
    }

    try {
      const searchUrl = new URL('https://archive.org/advancedsearch.php');
      searchUrl.searchParams.set(
        'q',
        `mediatype:(audio) AND (${query}) AND (licenseurl:*creativecommons* OR licenseurl:*publicdomain*)`
      );
      searchUrl.searchParams.append('fl[]', 'identifier');
      searchUrl.searchParams.append('fl[]', 'title');
      searchUrl.searchParams.append('fl[]', 'creator');
      searchUrl.searchParams.append('fl[]', 'year');
      searchUrl.searchParams.append('fl[]', 'licenseurl');
      searchUrl.searchParams.set('rows', String(Math.min(limit, 6)));
      searchUrl.searchParams.set('page', '1');
      searchUrl.searchParams.set('output', 'json');

      const res = await fetch(searchUrl.toString(), { signal: AbortSignal.timeout(3500) });
      if (res.ok) {
        const data = (await res.json()) as {
          response?: { docs?: ArchiveSearchDoc[] };
        };
        const docs = data.response?.docs ?? [];
        const mapped: CatalogTrack[] = docs
          .filter((d) => Boolean(d.identifier && d.title))
          .map((d) => {
            const creator = Array.isArray(d.creator)
              ? d.creator[0]
              : d.creator || 'Internet Archive Artist';
            return {
              id: `ia_${d.identifier}`,
              source: 'internet_archive',
              externalId: d.identifier,
              title: d.title || d.identifier,
              artist: creator,
              album: 'Internet Archive Open Audio',
              genre: 'Ambient',
              durationSeconds: 215,
              artworkUrl: `https://archive.org/services/img/${d.identifier}`,
              streamUrl: `https://archive.org/download/${d.identifier}/${d.identifier}_vbr.mp3`,
              downloadUrl: `https://archive.org/download/${d.identifier}`,
              qualityBadge: 'FLAC',
              license: d.licenseurl || 'Creative Commons (Internet Archive)',
              releaseYear: Number(d.year) || 2024,
              waveform: [0.3, 0.5, 0.7, 0.6, 0.8, 0.4, 0.75, 0.62, 0.51, 0.84],
              dominantColor: '#06B6D4',
            };
          });

        if (mapped.length > 0) {
          return [...localMatches, ...mapped].slice(0, limit);
        }
      }
    } catch {
      // Fallback to curated Internet Archive catalog
    }

    return localMatches.length > 0
      ? localMatches.slice(0, limit)
      : INITIAL_LEGAL_CATALOG.filter((t) => t.source === 'internet_archive').slice(0, limit);
  }

  async getTrending(limit = 8): Promise<CatalogTrack[]> {
    return INITIAL_LEGAL_CATALOG.filter((t) => t.source === 'internet_archive').slice(0, limit);
  }

  async getTrackById(id: string): Promise<CatalogTrack | null> {
    const found = INITIAL_LEGAL_CATALOG.find(
      (t) => t.source === 'internet_archive' && (t.id === id || t.externalId === id)
    );
    return found ?? null;
  }

  async resolveDownloadUrl(
    externalId: string,
    preferredQuality: 'FLAC' | '320kbps' = 'FLAC'
  ): Promise<{ downloadUrl: string; qualityBadge: 'FLAC' | '320kbps'; license: string } | null> {
    const found = INITIAL_LEGAL_CATALOG.find(
      (t) =>
        t.source === 'internet_archive' &&
        (t.externalId === externalId || t.id === externalId)
    );
    if (found && found.downloadUrl) {
      return {
        downloadUrl: `${found.downloadUrl}?quality=${preferredQuality.toLowerCase()}`,
        qualityBadge: preferredQuality,
        license: found.license,
      };
    }

    const cleanId = externalId.replace(/^ia_/, '');
    return {
      downloadUrl: `https://archive.org/download/${cleanId}/${cleanId}.${preferredQuality === 'FLAC' ? 'flac' : 'mp3'}`,
      qualityBadge: preferredQuality,
      license: 'Creative Commons / Public Domain (Internet Archive)',
    };
  }
}
