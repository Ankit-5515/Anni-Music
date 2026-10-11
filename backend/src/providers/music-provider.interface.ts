import { CatalogTrack } from '../data/catalog.js';

export type ProviderSource = 'jamendo' | 'internet_archive' | 'youtube';

export interface MusicSourceProvider {
  readonly sourceName: ProviderSource;
  readonly supportsDirectStream: boolean;
  readonly supportsLegalDownload: boolean;

  /**
   * Search tracks on this provider matching the query.
   */
  searchTracks(query: string, limit?: number): Promise<CatalogTrack[]>;

  /**
   * Return trending or featured tracks from this provider.
   */
  getTrending(limit?: number): Promise<CatalogTrack[]>;

  /**
   * Look up a single track by its provider-prefixed ID or external ID.
   */
  getTrackById(id: string): Promise<CatalogTrack | null>;

  /**
   * Resolve the highest available quality legal download URL (FLAC / 320kbps).
   * Must return null for providers that do not permit audio file downloads (e.g., YouTube).
   */
  resolveDownloadUrl(
    externalId: string,
    preferredQuality?: 'FLAC' | '320kbps'
  ): Promise<{ downloadUrl: string; qualityBadge: 'FLAC' | '320kbps'; license: string } | null>;
}
