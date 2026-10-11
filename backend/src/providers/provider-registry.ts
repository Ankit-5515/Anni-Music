import { CatalogTrack } from '../data/catalog.js';
import { dbStore } from '../db/store.js';
import { cacheService } from '../services/cache.js';
import { InternetArchiveProvider } from './internet-archive.provider.js';
import { JamendoProvider } from './jamendo.provider.js';
import { MusicSourceProvider, ProviderSource } from './music-provider.interface.js';
import { YouTubeProvider } from './youtube.provider.js';

export class ProviderRegistry {
  private providers = new Map<ProviderSource, MusicSourceProvider>();

  constructor() {
    this.register(new JamendoProvider());
    this.register(new InternetArchiveProvider());
    this.register(new YouTubeProvider());
  }

  register(provider: MusicSourceProvider): void {
    this.providers.set(provider.sourceName, provider);
  }

  getProvider(source: ProviderSource): MusicSourceProvider | undefined {
    return this.providers.get(source);
  }

  getAllProviders(): MusicSourceProvider[] {
    return Array.from(this.providers.values());
  }

  async searchUnified(
    query: string,
    sources?: ProviderSource[],
    limitPerProvider = 8
  ): Promise<{
    query: string;
    total: number;
    results: CatalogTrack[];
    byProvider: Record<string, CatalogTrack[]>;
  }> {
    const activeSources: ProviderSource[] =
      sources && sources.length > 0
        ? sources
        : ['jamendo', 'internet_archive', 'youtube'];

    const cacheKey = `search:${query.toLowerCase().trim()}:${activeSources.sort().join(',')}:${limitPerProvider}`;
    const cached = await cacheService.get<{
      query: string;
      total: number;
      results: CatalogTrack[];
      byProvider: Record<string, CatalogTrack[]>;
    }>(cacheKey);
    if (cached) return cached;

    const byProvider: Record<string, CatalogTrack[]> = {};
    const allResults: CatalogTrack[] = [];

    await Promise.all(
      activeSources.map(async (sourceName) => {
        const provider = this.providers.get(sourceName);
        if (!provider) return;
        const tracks = await provider.searchTracks(query, limitPerProvider);
        byProvider[sourceName] = tracks;
        for (const t of tracks) {
          dbStore.upsertTrack(t);
          allResults.push(t);
        }
      })
    );

    const payload = {
      query,
      total: allResults.length,
      results: allResults,
      byProvider,
    };

    await cacheService.set(cacheKey, payload, 180);
    return payload;
  }
}

export const providerRegistry = new ProviderRegistry();
