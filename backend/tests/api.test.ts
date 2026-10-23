import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { dbStore } from '../src/db/store.js';
import { providerRegistry } from '../src/providers/provider-registry.js';

describe('Anni Music REST API — Unit & Integration Suite', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    app = await buildApp();
    await app.ready();
  });

  beforeEach(() => {
    dbStore.resetForTests();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('Health & OpenAPI', () => {
    it('returns healthy status from GET /api/v1/health', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/health',
      });
      expect(res.statusCode).toBe(200);
      const body = res.json();
      expect(body.status).toBe('ok');
      expect(body.service).toBe('Anni Music API');
      expect(body.dependencies.providers).toEqual(['jamendo', 'internet_archive', 'youtube', 'jiosaavn']);
    });

    it('serves OpenAPI specification from /docs/json', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/docs/json',
      });
      expect(res.statusCode).toBe(200);
      const spec = res.json();
      expect(spec.openapi).toBeDefined();
      expect(spec.info.title).toBe('Anni Music REST API');
    });
  });

  describe('Auth Module (/api/v1/auth)', () => {
    it('registers a new user, logs in, refreshes tokens, updates profile, and deletes account', async () => {
      // 1. Register
      const regRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/register',
        payload: {
          email: 'shiva@annimusic.app',
          password: 'SuperSecurePassword123!',
          displayName: 'Shiva Audiophile',
        },
      });
      expect(regRes.statusCode).toBe(201);
      const regData = regRes.json();
      expect(regData.user.email).toBe('shiva@annimusic.app');
      expect(regData.accessToken).toBeDefined();
      expect(regData.refreshToken).toBeDefined();

      // 2. Login
      const loginRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'shiva@annimusic.app',
          password: 'SuperSecurePassword123!',
        },
      });
      expect(loginRes.statusCode).toBe(200);
      const loginData = loginRes.json();
      expect(loginData.accessToken).toBeDefined();

      // 3. Refresh token rotation
      const refreshRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/refresh',
        payload: {
          refreshToken: loginData.refreshToken,
        },
      });
      expect(refreshRes.statusCode).toBe(200);
      const refreshData = refreshRes.json();
      expect(refreshData.refreshToken).not.toBe(loginData.refreshToken);

      // Old refresh token should now be revoked
      const reusedRefreshRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/refresh',
        payload: {
          refreshToken: loginData.refreshToken,
        },
      });
      expect(reusedRefreshRes.statusCode).toBe(401);

      // 4. Update profile
      const patchRes = await app.inject({
        method: 'PATCH',
        url: '/api/v1/auth/profile',
        headers: {
          authorization: `Bearer ${refreshData.accessToken}`,
        },
        payload: {
          displayName: 'Shiva Master Studio',
          bio: 'FLAC & Vinyl Collector',
          analyticsOptIn: false,
        },
      });
      expect(patchRes.statusCode).toBe(200);
      expect(patchRes.json().user.displayName).toBe('Shiva Master Studio');
      expect(patchRes.json().user.analyticsOptIn).toBe(false);

      // 5. Delete account
      const delRes = await app.inject({
        method: 'DELETE',
        url: '/api/v1/auth/account',
        headers: {
          authorization: `Bearer ${refreshData.accessToken}`,
        },
      });
      expect(delRes.statusCode).toBe(200);
      expect(delRes.json().success).toBe(true);
    });

    it('supports Google Sign-In via POST /api/v1/auth/google', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/google',
        payload: {
          idToken: 'mock_google_oauth_jwt_token_value_123456',
          email: 'google.user@annimusic.app',
          displayName: 'Google Music Lover',
        },
      });
      expect(res.statusCode).toBe(200);
      expect(res.json().user.email).toBe('google.user@annimusic.app');
      expect(res.json().accessToken).toBeDefined();
    });

    it('handles password reset flow (forgot-password -> reset-password)', async () => {
      // 1. Request password reset
      const forgotRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/forgot-password',
        payload: {
          email: 'demo@annimusic.app',
        },
      });
      expect(forgotRes.statusCode).toBe(200);
      const token = forgotRes.json().devToken;
      expect(token).toBeDefined();

      // 2. Submit new password
      const resetRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/reset-password',
        payload: {
          email: 'demo@annimusic.app',
          token,
          newPassword: 'BrandNewPassword2026!',
        },
      });
      expect(resetRes.statusCode).toBe(200);
      expect(resetRes.json().success).toBe(true);

      // 3. Login with new password
      const newLoginRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'demo@annimusic.app',
          password: 'BrandNewPassword2026!',
        },
      });
      expect(newLoginRes.statusCode).toBe(200);
      expect(newLoginRes.json().accessToken).toBeDefined();
    });

    it('returns user listening stats from GET /api/v1/auth/stats', async () => {
      const loginRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'demo@annimusic.app',
          password: 'AnniMusic2026!',
        },
      });
      const token = loginRes.json().accessToken as string;

      const statsRes = await app.inject({
        method: 'GET',
        url: '/api/v1/auth/stats',
        headers: { authorization: `Bearer ${token}` },
      });
      expect(statsRes.statusCode).toBe(200);
      const body = statsRes.json();
      expect(body.stats).toBeDefined();
      expect(typeof body.stats.playlistsCount).toBe('number');
      expect(typeof body.stats.likedSongsCount).toBe('number');
      expect(typeof body.stats.hoursListened).toBe('number');
    });
  });

  describe('Playlists & Share Links (/api/v1/playlists)', () => {
    it('creates a playlist, adds/reorders/removes tracks, exports M3U, and resolves public share links', async () => {
      const loginRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'demo@annimusic.app',
          password: 'AnniMusic2026!',
        },
      });
      const token = loginRes.json().accessToken as string;

      // Create playlist
      const createRes = await app.inject({
        method: 'POST',
        url: '/api/v1/playlists',
        headers: { authorization: `Bearer ${token}` },
        payload: {
          name: 'Audiophile Test Session',
          description: 'Reference tracks for planar magnetic headphones',
          isPublic: true,
          trackIds: ['jamendo_1884921', 'ia_cc_flac_001'],
        },
      });
      expect(createRes.statusCode).toBe(201);
      const created = createRes.json().playlist;
      expect(created.resolvedTracks.length).toBe(2);

      // Add a 3rd track
      const addRes = await app.inject({
        method: 'POST',
        url: `/api/v1/playlists/${created.id}/tracks`,
        headers: { authorization: `Bearer ${token}` },
        payload: { trackId: 'jamendo_1902341' },
      });
      expect(addRes.statusCode).toBe(200);
      expect(addRes.json().playlist.resolvedTracks.length).toBe(3);

      // Reorder tracks
      const reorderRes = await app.inject({
        method: 'PUT',
        url: `/api/v1/playlists/${created.id}/reorder`,
        headers: { authorization: `Bearer ${token}` },
        payload: {
          orderedTrackIds: ['jamendo_1902341', 'ia_cc_flac_001', 'jamendo_1884921'],
        },
      });
      expect(reorderRes.statusCode).toBe(200);
      expect(reorderRes.json().playlist.resolvedTracks[0].id).toBe('jamendo_1902341');

      // Resolve public share link
      const shareRes = await app.inject({
        method: 'GET',
        url: `/api/v1/playlists/share/${created.shareSlug}`,
      });
      expect(shareRes.statusCode).toBe(200);
      expect(shareRes.json().playlist.name).toBe('Audiophile Test Session');

      // Export M3U
      const m3uRes = await app.inject({
        method: 'GET',
        url: `/api/v1/playlists/${created.id}/export.m3u`,
      });
      expect(m3uRes.statusCode).toBe(200);
      expect(m3uRes.body).toContain('#EXTM3U');
      expect(m3uRes.body).toContain('Solaris Pulse');
    });
  });

  describe('MusicSourceProviders, Unified Search, Lyrics & Signed Downloads', () => {
    it('implements Jamendo, InternetArchive, and YouTube providers with strict ToS compliance', async () => {
      const jamendo = providerRegistry.getProvider('jamendo')!;
      const ia = providerRegistry.getProvider('internet_archive')!;
      const yt = providerRegistry.getProvider('youtube')!;
      const jiosaavn = providerRegistry.getProvider('jiosaavn')!;

      expect(jamendo.supportsLegalDownload).toBe(true);
      expect(ia.supportsLegalDownload).toBe(true);
      expect(yt.supportsLegalDownload).toBe(false);
      expect(yt.supportsDirectStream).toBe(false);
      expect(jiosaavn.supportsDirectStream).toBe(true);
      expect(jiosaavn.supportsLegalDownload).toBe(false);

      const ytDownload = await yt.resolveDownloadUrl('jfKfPfyJRdk');
      expect(ytDownload).toBeNull();
    });

    it('performs unified search across providers via GET /api/v1/search', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/search?q=Midnight',
      });
      expect(res.statusCode).toBe(200);
      const data = res.json();
      expect(data.total).toBeGreaterThan(0);
      expect(data.byProvider.jamendo).toBeDefined();
      expect(data.byProvider.internet_archive).toBeDefined();
    });

    it('searches Indian songs (Bollywood, Punjabi, etc.) via JioSaavn provider', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/api/v1/search?q=Kesariya',
      });
      expect(res.statusCode).toBe(200);
      const data = res.json();
      expect(data.total).toBeGreaterThan(0);
      expect(data.results.some((t: any) => t.genre === 'Bollywood' || t.genre === 'Hindi')).toBe(true);
      expect(data.byProvider.jiosaavn).toBeDefined();
    });

    it('returns signed download URLs for Jamendo/InternetArchive and rejects YouTube downloads with 403', async () => {
      // Legal FLAC download from Jamendo
      const legalRes = await app.inject({
        method: 'POST',
        url: '/api/v1/downloads/sign',
        payload: {
          trackId: 'jamendo_1884921',
          preferredQuality: 'FLAC',
        },
      });
      expect(legalRes.statusCode).toBe(200);
      const legalData = legalRes.json();
      expect(legalData.qualityBadge).toBe('FLAC');
      expect(legalData.signedUrl).toContain('sig=');

      // Verify YouTube download is rejected with 403 Forbidden
      const ytRes = await app.inject({
        method: 'POST',
        url: '/api/v1/downloads/sign',
        payload: {
          trackId: 'youtube_jfKfPfyJRdk',
          preferredQuality: 'FLAC',
        },
      });
      expect(ytRes.statusCode).toBe(403);
    });

    it('returns synced LRC lyrics and personalized recommendations', async () => {
      const lrcRes = await app.inject({
        method: 'GET',
        url: '/api/v1/lyrics?trackId=jamendo_1884921',
      });
      expect(lrcRes.statusCode).toBe(200);
      expect(lrcRes.json().syncedLrc).toContain('[00:12.40]');

      const recRes = await app.inject({
        method: 'GET',
        url: '/api/v1/recommendations',
      });
      expect(recRes.statusCode).toBe(200);
      expect(recRes.json().madeForYouMixes.length).toBeGreaterThanOrEqual(3);
    });
  });

  describe('Cloud Sync (/api/v1/sync)', () => {
    it('syncs favorites, play history, and equalizer/audio settings across devices', async () => {
      const loginRes = await app.inject({
        method: 'POST',
        url: '/api/v1/auth/login',
        payload: {
          email: 'demo@annimusic.app',
          password: 'AnniMusic2026!',
        },
      });
      const token = loginRes.json().accessToken as string;

      const syncRes = await app.inject({
        method: 'POST',
        url: '/api/v1/sync',
        headers: { authorization: `Bearer ${token}` },
        payload: {
          favoriteTrackIdsToAdd: ['ia_cc_classical_003'],
          playEvents: [{ trackId: 'ia_cc_classical_003', listenedSeconds: 301, completed: true }],
          settings: {
            themeMode: 'amoled',
            crossfadeSeconds: 6,
            equalizerPreset: 'Deep Bass',
          },
        },
      });
      expect(syncRes.statusCode).toBe(200);
      const synced = syncRes.json();
      expect(synced.settings.themeMode).toBe('amoled');
      expect(synced.settings.crossfadeSeconds).toBe(6);
      expect(synced.favorites.some((t: { id: string }) => t.id === 'ia_cc_classical_003')).toBe(
        true
      );
    });
  });
});
