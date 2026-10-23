import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { INITIAL_LEGAL_CATALOG, CatalogTrack } from '../data/catalog.js';

export interface UserRecord {
  id: string;
  email: string;
  passwordHash: string | null;
  googleId: string | null;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  analyticsOptIn: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface RefreshTokenRecord {
  id: string;
  tokenHash: string;
  userId: string;
  expiresAt: string;
  revokedAt: string | null;
  createdAt: string;
}

export interface PlaylistTrackItem {
  trackId: string;
  position: number;
  addedAt: string;
}

export interface PlaylistRecord {
  id: string;
  userId: string;
  name: string;
  description: string | null;
  coverUrl: string | null;
  isPublic: boolean;
  shareSlug: string;
  tracks: PlaylistTrackItem[];
  createdAt: string;
  updatedAt: string;
}

export interface FavoriteRecord {
  userId: string;
  trackId: string;
  createdAt: string;
}

export interface PlayHistoryRecord {
  id: string;
  userId: string;
  trackId: string;
  playedAt: string;
  listenedSeconds: number;
  completed: boolean;
  completionRate: number;
}

export interface UserSettingsRecord {
  userId: string;
  themeMode: 'dark' | 'amoled' | 'light';
  streamingQuality: 'FLAC' | '320kbps' | '192kbps';
  downloadQuality: 'FLAC' | '320kbps';
  crossfadeSeconds: number;
  gaplessPlayback: boolean;
  replayGain: boolean;
  equalizerEnabled: boolean;
  equalizerPreset: string;
  equalizerBands: number[];
  bassBoostStrength: number;
  virtualizerStrength: number;
  wifiOnlyDownloads: boolean;
  updatedAt: string;
}

export interface LyricsCacheRecord {
  trackKey: string;
  title: string;
  artist: string;
  syncedLrc: string;
  plainLyrics: string;
  source: string;
  updatedAt: string;
}

export interface AnalyticsEventRecord {
  id: string;
  userId: string | null;
  eventType: string;
  properties: Record<string, unknown>;
  appVersion: string;
  platform: string;
  createdAt: string;
}

interface DatabaseSchema {
  users: UserRecord[];
  refreshTokens: RefreshTokenRecord[];
  tracks: CatalogTrack[];
  playlists: PlaylistRecord[];
  favorites: FavoriteRecord[];
  playHistory: PlayHistoryRecord[];
  userSettings: UserSettingsRecord[];
  lyricsCache: LyricsCacheRecord[];
  analytics: AnalyticsEventRecord[];
}

export class AnniDataStore {
  private dbPath: string;
  private state: DatabaseSchema;
  private resetTokens = new Map<string, { email: string; token: string; expiresAt: number }>();

  constructor() {
    const dataDir = path.resolve(process.cwd(), 'data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    this.dbPath = path.join(dataDir, 'anni_db.json');
    this.state = this.loadOrSeed();
  }

  private loadOrSeed(): DatabaseSchema {
    if (fs.existsSync(this.dbPath) && process.env.NODE_ENV !== 'test') {
      try {
        const raw = fs.readFileSync(this.dbPath, 'utf-8');
        const parsed = JSON.parse(raw) as DatabaseSchema;
        if (parsed.tracks && parsed.tracks.length > 0) {
          return parsed;
        }
      } catch {
        // Fallback to fresh seed
      }
    }
    return this.createSeedState();
  }

  public createSeedState(): DatabaseSchema {
    const now = new Date().toISOString();
    const demoUserId = 'usr_anni_demo_001';
    const passwordHash = bcrypt.hashSync('AnniMusic2026!', 10);

    const demoUser: UserRecord = {
      id: demoUserId,
      email: 'demo@annimusic.app',
      passwordHash,
      googleId: null,
      displayName: 'Aria Vance',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      bio: 'Audiophile & synthwave curator. Exploring lossless soundscapes on Anni Music.',
      analyticsOptIn: true,
      createdAt: now,
      updatedAt: now,
    };

    const defaultSettings: UserSettingsRecord = {
      userId: demoUserId,
      themeMode: 'dark',
      streamingQuality: 'FLAC',
      downloadQuality: 'FLAC',
      crossfadeSeconds: 4,
      gaplessPlayback: true,
      replayGain: true,
      equalizerEnabled: true,
      equalizerPreset: 'Signature Cinema',
      equalizerBands: [2.5, 4.0, 2.0, 0.0, -1.0, 0.5, 2.0, 3.5, 4.0, 3.0],
      bassBoostStrength: 450,
      virtualizerStrength: 300,
      wifiOnlyDownloads: false,
      updatedAt: now,
    };

    const playlists: PlaylistRecord[] = [
      {
        id: 'pl_midnight_odyssey',
        userId: demoUserId,
        name: 'Midnight Obsidian Drive',
        description: 'Cinematic synthwave, deep electronic, and lossless nocturnal grooves.',
        coverUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
        isPublic: true,
        shareSlug: 'midnight-obsidian-drive',
        tracks: [
          { trackId: 'jamendo_1884921', position: 0, addedAt: now },
          { trackId: 'jamendo_1902341', position: 1, addedAt: now },
          { trackId: 'jamendo_1992011', position: 2, addedAt: now },
          { trackId: 'jamendo_2059104', position: 3, addedAt: now },
        ],
        createdAt: now,
        updatedAt: now,
      },
      {
        id: 'pl_lossless_sanctuary',
        userId: demoUserId,
        name: '24-Bit Studio Reference (FLAC)',
        description: 'Pure uncompressed acoustic, ambient, and chamber recordings for critical listening.',
        coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=800&auto=format&fit=crop&q=80',
        isPublic: true,
        shareSlug: 'lossless-studio-reference',
        tracks: [
          { trackId: 'ia_cc_flac_001', position: 0, addedAt: now },
          { trackId: 'ia_cc_jazz_002', position: 1, addedAt: now },
          { trackId: 'ia_cc_classical_003', position: 2, addedAt: now },
        ],
        createdAt: now,
        updatedAt: now,
      },
      {
        id: 'pl_lofi_focus',
        userId: demoUserId,
        name: 'Velvet Lo-Fi & Late Coding',
        description: 'Warm analog keys, dusty vinyl beats, and deep focus rhythms.',
        coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
        isPublic: true,
        shareSlug: 'velvet-lofi-coding',
        tracks: [
          { trackId: 'jamendo_1948102', position: 0, addedAt: now },
          { trackId: 'ia_cc_indie_004', position: 1, addedAt: now },
          { trackId: 'youtube_jfKfPfyJRdk', position: 2, addedAt: now },
        ],
        createdAt: now,
        updatedAt: now,
      },
    ];

    const favorites: FavoriteRecord[] = [
      { userId: demoUserId, trackId: 'jamendo_1884921', createdAt: now },
      { userId: 'usr_anni_demo_001', trackId: 'ia_cc_flac_001', createdAt: now },
      { userId: 'usr_anni_demo_001', trackId: 'jamendo_1902341', createdAt: now },
      { userId: 'usr_anni_demo_001', trackId: 'jamendo_1948102', createdAt: now },
    ];

    const playHistory: PlayHistoryRecord[] = [
      {
        id: 'ph_1',
        userId: demoUserId,
        trackId: 'jamendo_1884921',
        playedAt: new Date(Date.now() - 1000 * 60 * 15).toISOString(),
        listenedSeconds: 224,
        completed: true,
        completionRate: 1.0,
      },
      {
        id: 'ph_2',
        userId: demoUserId,
        trackId: 'jamendo_1902341',
        playedAt: new Date(Date.now() - 1000 * 60 * 45).toISOString(),
        listenedSeconds: 198,
        completed: true,
        completionRate: 1.0,
      },
      {
        id: 'ph_3',
        userId: demoUserId,
        trackId: 'ia_cc_flac_001',
        playedAt: new Date(Date.now() - 1000 * 60 * 120).toISOString(),
        listenedSeconds: 240,
        completed: true,
        completionRate: 0.94,
      },
      {
        id: 'ph_4',
        userId: demoUserId,
        trackId: 'jamendo_1948102',
        playedAt: new Date(Date.now() - 1000 * 60 * 240).toISOString(),
        listenedSeconds: 185,
        completed: true,
        completionRate: 1.0,
      },
    ];

    const lyricsCache: LyricsCacheRecord[] = INITIAL_LEGAL_CATALOG.filter((t) => t.syncedLrc).map(
      (t) => ({
        trackKey: `${t.artist.toLowerCase().trim()}::${t.title.toLowerCase().trim()}`,
        title: t.title,
        artist: t.artist,
        syncedLrc: t.syncedLrc!,
        plainLyrics: t.syncedLrc!.replace(/\[\d{2}:\d{2}\.\d{2}\]\s*/g, ''),
        source: 'anni-seeded-lrc',
        updatedAt: now,
      })
    );

    const seeded: DatabaseSchema = {
      users: [demoUser],
      refreshTokens: [],
      tracks: [...INITIAL_LEGAL_CATALOG],
      playlists,
      favorites,
      playHistory,
      userSettings: [defaultSettings],
      lyricsCache,
      analytics: [],
    };

    this.state = seeded;
    this.persist();
    return seeded;
  }

  public persist(): void {
    if (process.env.NODE_ENV === 'test') return;
    try {
      fs.writeFileSync(this.dbPath, JSON.stringify(this.state, null, 2), 'utf-8');
    } catch {
      // Ignore write error in read-only environments
    }
  }

  public resetForTests(): void {
    this.state = this.createSeedState();
  }

  // Users
  findUserByEmail(email: string): UserRecord | undefined {
    return this.state.users.find((u) => u.email.toLowerCase() === email.toLowerCase());
  }

  findUserById(id: string): UserRecord | undefined {
    return this.state.users.find((u) => u.id === id);
  }

  findUserByGoogleId(googleId: string): UserRecord | undefined {
    return this.state.users.find((u) => u.googleId === googleId);
  }

  createUser(input: {
    email: string;
    passwordHash?: string | null;
    googleId?: string | null;
    displayName: string;
    avatarUrl?: string | null;
  }): UserRecord {
    const now = new Date().toISOString();
    const user: UserRecord = {
      id: `usr_${crypto.randomUUID()}`,
      email: input.email.toLowerCase().trim(),
      passwordHash: input.passwordHash ?? null,
      googleId: input.googleId ?? null,
      displayName: input.displayName.trim(),
      avatarUrl: input.avatarUrl ?? null,
      bio: 'Music lover on Anni Music.',
      analyticsOptIn: true,
      createdAt: now,
      updatedAt: now,
    };
    this.state.users.push(user);

    // Create default user settings
    this.state.userSettings.push({
      userId: user.id,
      themeMode: 'dark',
      streamingQuality: 'FLAC',
      downloadQuality: 'FLAC',
      crossfadeSeconds: 4,
      gaplessPlayback: true,
      replayGain: true,
      equalizerEnabled: true,
      equalizerPreset: 'Signature Cinema',
      equalizerBands: [2.5, 4.0, 2.0, 0.0, -1.0, 0.5, 2.0, 3.5, 4.0, 3.0],
      bassBoostStrength: 450,
      virtualizerStrength: 300,
      wifiOnlyDownloads: false,
      updatedAt: now,
    });

    this.persist();
    return user;
  }

  updateUser(
    userId: string,
    patch: Partial<Pick<UserRecord, 'displayName' | 'avatarUrl' | 'bio' | 'analyticsOptIn'>>
  ): UserRecord | null {
    const user = this.findUserById(userId);
    if (!user) return null;
    if (patch.displayName !== undefined) user.displayName = patch.displayName;
    if (patch.avatarUrl !== undefined) user.avatarUrl = patch.avatarUrl;
    if (patch.bio !== undefined) user.bio = patch.bio;
    if (patch.analyticsOptIn !== undefined) user.analyticsOptIn = patch.analyticsOptIn;
    user.updatedAt = new Date().toISOString();
    this.persist();
    return user;
  }

  deleteUser(userId: string): boolean {
    const before = this.state.users.length;
    this.state.users = this.state.users.filter((u) => u.id !== userId);
    this.state.refreshTokens = this.state.refreshTokens.filter((rt) => rt.userId !== userId);
    this.state.playlists = this.state.playlists.filter((p) => p.userId !== userId);
    this.state.favorites = this.state.favorites.filter((f) => f.userId !== userId);
    this.state.playHistory = this.state.playHistory.filter((ph) => ph.userId !== userId);
    this.state.userSettings = this.state.userSettings.filter((s) => s.userId !== userId);
    this.persist();
    return this.state.users.length < before;
  }

  createPasswordResetToken(email: string): string {
    const token = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 15 * 60 * 1000;
    this.resetTokens.set(token, { email: email.toLowerCase(), token, expiresAt });
    return token;
  }

  verifyAndResetPassword(email: string, token: string, newPasswordHash: string): boolean {
    const record = this.resetTokens.get(token);
    if (!record || record.email !== email.toLowerCase() || record.expiresAt < Date.now()) {
      return false;
    }
    const user = this.findUserByEmail(email);
    if (!user) return false;
    user.passwordHash = newPasswordHash;
    user.updatedAt = new Date().toISOString();
    this.resetTokens.delete(token);
    this.persist();
    return true;
  }

  getUserListeningStats(userId: string): { playlistsCount: number; likedSongsCount: number; hoursListened: number } {
    const playlistsCount = this.state.playlists.filter((p) => p.userId === userId).length;
    const likedSongsCount = this.state.favorites.filter((f) => f.userId === userId).length;
    const totalPlaySeconds = this.state.playHistory
      .filter((h) => h.userId === userId)
      .reduce((acc, curr) => acc + (curr.listenedSeconds || 0), 0);
    const hoursListened = Number((totalPlaySeconds / 3600).toFixed(1));
    return { playlistsCount, likedSongsCount, hoursListened };
  }

  // Refresh Tokens
  saveRefreshToken(userId: string, rawToken: string, expiresAt: Date): RefreshTokenRecord {
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
    const record: RefreshTokenRecord = {
      id: `rt_${crypto.randomUUID()}`,
      tokenHash,
      userId,
      expiresAt: expiresAt.toISOString(),
      revokedAt: null,
      createdAt: new Date().toISOString(),
    };
    this.state.refreshTokens.push(record);
    this.persist();
    return record;
  }

  findValidRefreshToken(rawToken: string): RefreshTokenRecord | null {
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
    const found = this.state.refreshTokens.find(
      (rt) => rt.tokenHash === tokenHash && rt.revokedAt === null
    );
    if (!found) return null;
    if (new Date(found.expiresAt).getTime() < Date.now()) {
      return null;
    }
    return found;
  }

  revokeRefreshToken(rawToken: string): void {
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
    for (const rt of this.state.refreshTokens) {
      if (rt.tokenHash === tokenHash) {
        rt.revokedAt = new Date().toISOString();
      }
    }
    this.persist();
  }

  // Tracks
  getAllTracks(): CatalogTrack[] {
    return this.state.tracks;
  }

  getTrackById(id: string): CatalogTrack | undefined {
    return this.state.tracks.find((t) => t.id === id);
  }

  upsertTrack(track: CatalogTrack): CatalogTrack {
    const idx = this.state.tracks.findIndex((t) => t.id === track.id);
    if (idx >= 0) {
      this.state.tracks[idx] = { ...this.state.tracks[idx], ...track };
    } else {
      this.state.tracks.push(track);
    }
    this.persist();
    return track;
  }

  // Playlists
  getPlaylistsForUser(userId: string): Array<PlaylistRecord & { resolvedTracks: CatalogTrack[] }> {
    return this.state.playlists
      .filter((p) => p.userId === userId)
      .map((p) => this.hydratePlaylist(p));
  }

  getPlaylistById(id: string): (PlaylistRecord & { resolvedTracks: CatalogTrack[] }) | null {
    const p = this.state.playlists.find((item) => item.id === id);
    return p ? this.hydratePlaylist(p) : null;
  }

  getPlaylistByShareSlug(
    slug: string
  ): (PlaylistRecord & { resolvedTracks: CatalogTrack[] }) | null {
    const p = this.state.playlists.find((item) => item.shareSlug === slug && item.isPublic);
    return p ? this.hydratePlaylist(p) : null;
  }

  private hydratePlaylist(
    playlist: PlaylistRecord
  ): PlaylistRecord & { resolvedTracks: CatalogTrack[] } {
    const sorted = [...playlist.tracks].sort((a, b) => a.position - b.position);
    const resolvedTracks = sorted
      .map((item) => this.getTrackById(item.trackId))
      .filter((t): t is CatalogTrack => Boolean(t));
    return {
      ...playlist,
      tracks: sorted,
      resolvedTracks,
    };
  }

  createPlaylist(input: {
    userId: string;
    name: string;
    description?: string | null;
    coverUrl?: string | null;
    isPublic?: boolean;
    trackIds?: string[];
  }): PlaylistRecord & { resolvedTracks: CatalogTrack[] } {
    const now = new Date().toISOString();
    const slugBase = input.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
    const shareSlug = `${slugBase || 'playlist'}-${crypto.randomBytes(3).toString('hex')}`;

    const tracks: PlaylistTrackItem[] = (input.trackIds ?? []).map((trackId, index) => ({
      trackId,
      position: index,
      addedAt: now,
    }));

    const record: PlaylistRecord = {
      id: `pl_${crypto.randomUUID()}`,
      userId: input.userId,
      name: input.name.trim(),
      description: input.description ?? null,
      coverUrl:
        input.coverUrl ??
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
      isPublic: input.isPublic ?? true,
      shareSlug,
      tracks,
      createdAt: now,
      updatedAt: now,
    };
    this.state.playlists.push(record);
    this.persist();
    return this.hydratePlaylist(record);
  }

  updatePlaylist(
    id: string,
    userId: string,
    patch: {
      name?: string;
      description?: string | null;
      coverUrl?: string | null;
      isPublic?: boolean;
    }
  ): (PlaylistRecord & { resolvedTracks: CatalogTrack[] }) | null {
    const p = this.state.playlists.find((item) => item.id === id && item.userId === userId);
    if (!p) return null;
    if (patch.name !== undefined) p.name = patch.name.trim();
    if (patch.description !== undefined) p.description = patch.description;
    if (patch.coverUrl !== undefined) p.coverUrl = patch.coverUrl;
    if (patch.isPublic !== undefined) p.isPublic = patch.isPublic;
    p.updatedAt = new Date().toISOString();
    this.persist();
    return this.hydratePlaylist(p);
  }

  deletePlaylist(id: string, userId: string): boolean {
    const before = this.state.playlists.length;
    this.state.playlists = this.state.playlists.filter(
      (item) => !(item.id === id && item.userId === userId)
    );
    this.persist();
    return this.state.playlists.length < before;
  }

  addTrackToPlaylist(
    playlistId: string,
    userId: string,
    trackId: string,
    trackMetadata?: CatalogTrack
  ): (PlaylistRecord & { resolvedTracks: CatalogTrack[] }) | null {
    const p = this.state.playlists.find((item) => item.id === playlistId && item.userId === userId);
    if (!p) return null;
    if (trackMetadata) {
      this.upsertTrack(trackMetadata);
    }
    if (!p.tracks.some((t) => t.trackId === trackId)) {
      p.tracks.push({
        trackId,
        position: p.tracks.length,
        addedAt: new Date().toISOString(),
      });
      p.updatedAt = new Date().toISOString();
      this.persist();
    }
    return this.hydratePlaylist(p);
  }

  removeTrackFromPlaylist(
    playlistId: string,
    userId: string,
    trackId: string
  ): (PlaylistRecord & { resolvedTracks: CatalogTrack[] }) | null {
    const p = this.state.playlists.find((item) => item.id === playlistId && item.userId === userId);
    if (!p) return null;
    p.tracks = p.tracks
      .filter((t) => t.trackId !== trackId)
      .map((t, idx) => ({ ...t, position: idx }));
    p.updatedAt = new Date().toISOString();
    this.persist();
    return this.hydratePlaylist(p);
  }

  reorderPlaylistTracks(
    playlistId: string,
    userId: string,
    orderedTrackIds: string[]
  ): (PlaylistRecord & { resolvedTracks: CatalogTrack[] }) | null {
    const p = this.state.playlists.find((item) => item.id === playlistId && item.userId === userId);
    if (!p) return null;
    const now = new Date().toISOString();
    const existingMap = new Map(p.tracks.map((t) => [t.trackId, t]));
    p.tracks = orderedTrackIds.map((trackId, index) => ({
      trackId,
      position: index,
      addedAt: existingMap.get(trackId)?.addedAt ?? now,
    }));
    p.updatedAt = now;
    this.persist();
    return this.hydratePlaylist(p);
  }

  // Favorites
  getFavorites(userId: string): CatalogTrack[] {
    const favs = this.state.favorites.filter((f) => f.userId === userId);
    return favs
      .map((f) => this.getTrackById(f.trackId))
      .filter((t): t is CatalogTrack => Boolean(t));
  }

  toggleFavorite(
    userId: string,
    trackId: string,
    trackMetadata?: CatalogTrack
  ): { isFavorite: boolean; favorites: CatalogTrack[] } {
    if (trackMetadata) {
      this.upsertTrack(trackMetadata);
    }
    const existingIdx = this.state.favorites.findIndex(
      (f) => f.userId === userId && f.trackId === trackId
    );
    let isFavorite = false;
    if (existingIdx >= 0) {
      this.state.favorites.splice(existingIdx, 1);
      isFavorite = false;
    } else {
      this.state.favorites.push({
        userId,
        trackId,
        createdAt: new Date().toISOString(),
      });
      isFavorite = true;
    }
    this.persist();
    return { isFavorite, favorites: this.getFavorites(userId) };
  }

  // Play History
  getPlayHistory(
    userId: string,
    limit = 30
  ): Array<PlayHistoryRecord & { track?: CatalogTrack }> {
    return this.state.playHistory
      .filter((ph) => ph.userId === userId)
      .sort((a, b) => new Date(b.playedAt).getTime() - new Date(a.playedAt).getTime())
      .slice(0, limit)
      .map((ph) => ({
        ...ph,
        track: this.getTrackById(ph.trackId),
      }));
  }

  recordPlay(input: {
    userId: string;
    trackId: string;
    listenedSeconds?: number;
    completed?: boolean;
    trackMetadata?: CatalogTrack;
  }): PlayHistoryRecord {
    if (input.trackMetadata) {
      this.upsertTrack(input.trackMetadata);
    }
    const track = this.getTrackById(input.trackId);
    const duration = track?.durationSeconds || 200;
    const listened = input.listenedSeconds ?? duration;
    const record: PlayHistoryRecord = {
      id: `ph_${crypto.randomUUID()}`,
      userId: input.userId,
      trackId: input.trackId,
      playedAt: new Date().toISOString(),
      listenedSeconds: listened,
      completed: input.completed ?? true,
      completionRate: Math.min(1.0, Number((listened / duration).toFixed(2))),
    };
    this.state.playHistory.unshift(record);
    this.persist();
    return record;
  }

  // User Settings
  getUserSettings(userId: string): UserSettingsRecord {
    let settings = this.state.userSettings.find((s) => s.userId === userId);
    if (!settings) {
      settings = {
        userId,
        themeMode: 'dark',
        streamingQuality: 'FLAC',
        downloadQuality: 'FLAC',
        crossfadeSeconds: 4,
        gaplessPlayback: true,
        replayGain: true,
        equalizerEnabled: true,
        equalizerPreset: 'Signature Cinema',
        equalizerBands: [2.5, 4.0, 2.0, 0.0, -1.0, 0.5, 2.0, 3.5, 4.0, 3.0],
        bassBoostStrength: 450,
        virtualizerStrength: 300,
        wifiOnlyDownloads: false,
        updatedAt: new Date().toISOString(),
      };
      this.state.userSettings.push(settings);
      this.persist();
    }
    return settings;
  }

  updateUserSettings(
    userId: string,
    patch: Partial<Omit<UserSettingsRecord, 'userId' | 'updatedAt'>>
  ): UserSettingsRecord {
    const current = this.getUserSettings(userId);
    Object.assign(current, patch, { updatedAt: new Date().toISOString() });
    this.persist();
    return current;
  }

  // Lyrics Cache
  getLyrics(artist: string, title: string): LyricsCacheRecord | undefined {
    const key = `${artist.toLowerCase().trim()}::${title.toLowerCase().trim()}`;
    return this.state.lyricsCache.find((l) => l.trackKey === key);
  }

  saveLyrics(record: LyricsCacheRecord): void {
    const idx = this.state.lyricsCache.findIndex((l) => l.trackKey === record.trackKey);
    if (idx >= 0) {
      this.state.lyricsCache[idx] = record;
    } else {
      this.state.lyricsCache.push(record);
    }
    this.persist();
  }

  // Analytics
  recordAnalyticsEvent(input: {
    userId: string | null;
    eventType: string;
    properties?: Record<string, unknown>;
    appVersion?: string;
    platform?: string;
  }): { recorded: boolean; reason?: string } {
    if (input.userId) {
      const user = this.findUserById(input.userId);
      if (user && !user.analyticsOptIn) {
        return { recorded: false, reason: 'User opted out of analytics' };
      }
    }
    this.state.analytics.push({
      id: `ev_${crypto.randomUUID()}`,
      userId: input.userId,
      eventType: input.eventType,
      properties: input.properties ?? {},
      appVersion: input.appVersion ?? '1.0.0',
      platform: input.platform ?? 'android',
      createdAt: new Date().toISOString(),
    });
    this.persist();
    return { recorded: true };
  }
}

export const dbStore = new AnniDataStore();
