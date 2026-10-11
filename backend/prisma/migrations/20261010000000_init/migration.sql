-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT,
    "googleId" TEXT,
    "displayName" TEXT NOT NULL,
    "avatarUrl" TEXT,
    "bio" TEXT,
    "analyticsOptIn" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "userAgent" TEXT,
    "ipAddress" TEXT,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Track" (
    "id" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "externalId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "artist" TEXT NOT NULL,
    "album" TEXT NOT NULL,
    "genre" TEXT NOT NULL DEFAULT 'Electronic',
    "durationSeconds" INTEGER NOT NULL,
    "artworkUrl" TEXT NOT NULL,
    "streamUrl" TEXT,
    "downloadUrl" TEXT,
    "qualityBadge" TEXT NOT NULL DEFAULT '320kbps',
    "license" TEXT NOT NULL DEFAULT 'CC BY-NC-SA 4.0',
    "releaseYear" INTEGER,
    "waveform" DOUBLE PRECISION[],
    "dominantColor" TEXT NOT NULL DEFAULT '#8B5CF6',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Track_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Playlist" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "coverUrl" TEXT,
    "isPublic" BOOLEAN NOT NULL DEFAULT true,
    "shareSlug" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Playlist_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlaylistTrack" (
    "id" TEXT NOT NULL,
    "playlistId" TEXT NOT NULL,
    "trackId" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "addedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PlaylistTrack_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Favorite" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "trackId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Favorite_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlayHistory" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "trackId" TEXT NOT NULL,
    "playedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "listenedSeconds" INTEGER NOT NULL DEFAULT 0,
    "completed" BOOLEAN NOT NULL DEFAULT false,
    "completionRate" DOUBLE PRECISION NOT NULL DEFAULT 1.0,

    CONSTRAINT "PlayHistory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserSettings" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "themeMode" TEXT NOT NULL DEFAULT 'dark',
    "streamingQuality" TEXT NOT NULL DEFAULT 'FLAC',
    "downloadQuality" TEXT NOT NULL DEFAULT 'FLAC',
    "crossfadeSeconds" INTEGER NOT NULL DEFAULT 4,
    "gaplessPlayback" BOOLEAN NOT NULL DEFAULT true,
    "replayGain" BOOLEAN NOT NULL DEFAULT true,
    "equalizerEnabled" BOOLEAN NOT NULL DEFAULT true,
    "equalizerPreset" TEXT NOT NULL DEFAULT 'Signature Cinema',
    "equalizerBandsJson" TEXT NOT NULL DEFAULT '[2.5, 4.0, 2.0, 0.0, -1.0, 0.5, 2.0, 3.5, 4.0, 3.0]',
    "bassBoostStrength" INTEGER NOT NULL DEFAULT 450,
    "virtualizerStrength" INTEGER NOT NULL DEFAULT 300,
    "wifiOnlyDownloads" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LyricsCache" (
    "id" TEXT NOT NULL,
    "trackKey" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "artist" TEXT NOT NULL,
    "syncedLrc" TEXT NOT NULL,
    "plainLyrics" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'lrclib',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LyricsCache_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalyticsEvent" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "eventType" TEXT NOT NULL,
    "properties" TEXT NOT NULL DEFAULT '{}',
    "appVersion" TEXT NOT NULL DEFAULT '1.0.0',
    "platform" TEXT NOT NULL DEFAULT 'android',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AnalyticsEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
CREATE UNIQUE INDEX "User_googleId_key" ON "User"("googleId");
CREATE INDEX "User_email_idx" ON "User"("email");
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");
CREATE UNIQUE INDEX "Track_source_externalId_key" ON "Track"("source", "externalId");
CREATE INDEX "Track_title_artist_idx" ON "Track"("title", "artist");
CREATE INDEX "Track_genre_idx" ON "Track"("genre");
CREATE UNIQUE INDEX "Playlist_shareSlug_key" ON "Playlist"("shareSlug");
CREATE INDEX "Playlist_userId_idx" ON "Playlist"("userId");
CREATE INDEX "Playlist_shareSlug_idx" ON "Playlist"("shareSlug");
CREATE UNIQUE INDEX "PlaylistTrack_playlistId_trackId_key" ON "PlaylistTrack"("playlistId", "trackId");
CREATE INDEX "PlaylistTrack_playlistId_position_idx" ON "PlaylistTrack"("playlistId", "position");
CREATE UNIQUE INDEX "Favorite_userId_trackId_key" ON "Favorite"("userId", "trackId");
CREATE INDEX "Favorite_userId_idx" ON "Favorite"("userId");
CREATE INDEX "PlayHistory_userId_playedAt_idx" ON "PlayHistory"("userId", "playedAt" DESC);
CREATE INDEX "PlayHistory_trackId_idx" ON "PlayHistory"("trackId");
CREATE UNIQUE INDEX "UserSettings_userId_key" ON "UserSettings"("userId");
CREATE UNIQUE INDEX "LyricsCache_trackKey_key" ON "LyricsCache"("trackKey");
CREATE INDEX "AnalyticsEvent_eventType_createdAt_idx" ON "AnalyticsEvent"("eventType", "createdAt");

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Playlist" ADD CONSTRAINT "Playlist_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PlaylistTrack" ADD CONSTRAINT "PlaylistTrack_playlistId_fkey" FOREIGN KEY ("playlistId") REFERENCES "Playlist"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PlaylistTrack" ADD CONSTRAINT "PlaylistTrack_trackId_fkey" FOREIGN KEY ("trackId") REFERENCES "Track"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Favorite" ADD CONSTRAINT "Favorite_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Favorite" ADD CONSTRAINT "Favorite_trackId_fkey" FOREIGN KEY ("trackId") REFERENCES "Track"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PlayHistory" ADD CONSTRAINT "PlayHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PlayHistory" ADD CONSTRAINT "PlayHistory_trackId_fkey" FOREIGN KEY ("trackId") REFERENCES "Track"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "UserSettings" ADD CONSTRAINT "UserSettings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AnalyticsEvent" ADD CONSTRAINT "AnalyticsEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
