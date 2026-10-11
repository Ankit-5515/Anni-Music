# Anni Music — System Architecture & Technical Design

> **Tagline**: *"Your music. Your world."*
> **Stack**: Flutter 3.x (Clean Architecture + Riverpod + `just_audio` + `audio_service` + Drift/Hive) • Node.js 20 + Fastify + TypeScript + Prisma + PostgreSQL 16 + Redis 7 + MinIO S3

---

## 1. High-Level System Context

Anni Music is an offline-first, cloud-synchronized mobile music platform engineered to stream licensed independent and Creative Commons tracks (via Audius, Jamendo, Internet Archive, and Curated CC catalogs), play device-local audio files (`mp3`, `flac`, `wav`, `m4a`, `ogg`), render time-synced LRC lyrics, and synchronize user libraries across devices.

```mermaid
flowchart TB
    subgraph Client["📱 Anni Music Mobile App (Flutter / Android & iOS)"]
        UI["Presentation Layer\n(Glassmorphic Obsidian UI, Mini-Player, Full Player, Lyrics)"]
        Riverpod["State Management\n(Riverpod Notifiers & StreamProviders)"]
        AudioEngine["Native Audio Engine\n(just_audio + audio_service + MediaSession)"]
        LocalDB["Offline-First Persistence\n(Drift SQLite + Hive + AES-256 Encrypted Cache)"]
    end

    subgraph Cloud["☁️ Anni Music Cloud Backend (Fastify + TypeScript)"]
        Gateway["Fastify API Gateway\n(/api/v1/*, JWT Auth, Rate Limiter, Zod Validation)"]
        Aggregator["Legal Provider Aggregator\n(Parallel Search, Metadata Normalization, Deduplication)"]
        SyncEngine["Delta Cloud Sync Engine\n(Last-Write-Wins Conflict Resolution)"]
        RecEngine["Hybrid Recommendation Engine\n(Mood + Genre + Listening History Affinity)"]
    end

    subgraph Storage["🗄️ Data & Object Storage Layer"]
        Postgres[("PostgreSQL 16\n(Users, Playlists, History, Sync Log)")]
        Redis[("Redis 7\n(Search Cache, Rate Limits, Refresh Token Blacklist)")]
        MinIO[("MinIO / S3 Storage\n(User Uploads & Playlist Artwork)")]
    end

    subgraph External["🌐 Legal Music & Lyrics Providers"]
        Audius["Audius Decentralized Network API"]
        Jamendo["Jamendo Creative Commons API"]
        Archive["Internet Archive Open Audio"]
        LRCLIB["LRCLIB Synchronized Lyrics API"]
    end

    UI --> Riverpod
    Riverpod --> AudioEngine
    Riverpod --> LocalDB
    Riverpod <-->|"HTTPS REST / JSON"| Gateway
    AudioEngine <-->|"HTTP Range Byte Streaming / Offline File"| External
    AudioEngine <-->|"Cached Encrypted Audio"| LocalDB

    Gateway --> Aggregator
    Gateway --> SyncEngine
    Gateway --> RecEngine
    Gateway --> Postgres
    Gateway --> Redis
    Gateway --> MinIO

    Aggregator --> Audius
    Aggregator --> Jamendo
    Aggregator --> Archive
    Gateway --> LRCLIB
```

---

## 2. Mobile Application Architecture (Flutter Clean Architecture)

The `/app` directory enforces strict **Feature-First Clean Architecture** separated into three concentric layers (`domain`, `data`, `presentation`) plus shared `core` services.

```mermaid
flowchart LR
    subgraph Presentation["Presentation Layer"]
        Screens["Screens & Views\n(Home, Search, Library, Player, Profile)"]
        Widgets["Reusable Glassmorphic Widgets\n(MiniPlayer,SyncedLyricsView, Waveform)"]
        Controllers["Riverpod Notifiers\n(AudioPlayerController, SyncController)"]
    end

    subgraph Domain["Domain Layer (Pure Dart)"]
        Entities["Immutable Entities\n(Track, Playlist,SyncedLyricLine, UserProfile)"]
        UseCases["Use Cases\n(SearchTracks, ToggleFavorite, SyncLibrary)"]
        Repos["Repository Contracts\n(MusicRepository, AuthRepository, LyricsRepository)"]
    end

    subgraph Data["Data Layer"]
        RepoImpl["Repository Implementations\n(Offline-First Coordinator)"]
        RemoteDS["Remote Data Sources\n(Dio HTTP Client + JWT Interceptor)"]
        LocalDS["Local Data Sources\n(Hive Boxes, Drift SQLite, on_audio_query)"]
    end

    Screens --> Controllers
    Widgets --> Controllers
    Controllers --> UseCases
    UseCases --> Repos
    RepoImpl -.->|"implements"| Repos
    RepoImpl --> RemoteDS
    RepoImpl --> LocalDS
```

### Layer Responsibilities

| Layer | Directory | Responsibilities |
| :--- | :--- | :--- |
| **Core** | `app/lib/core/` | Theme (`#0A0A0F` obsidian dark palette, `#7C4DFF` electric violet, `#00E5FF` cyan accents), Dio HTTP client with automatic JWT token refresh, audio handler initialization, dependency injection. |
| **Domain** | `app/lib/features/*/domain/` | Pure Dart entities (`Track`, `Playlist`, `LyricLine`, `User`) and abstract repository interfaces with zero framework dependencies. |
| **Data** | `app/lib/features/*/data/` | DTO serialization, REST API calls, local Hive/SQLite caching, offline download manager, and `on_audio_query` local storage scanner. |
| **Presentation** | `app/lib/features/*/presentation/` | Riverpod `StateNotifier` / `AsyncNotifier` controllers, custom glassmorphic shaders, animated mini-player bar, full-screen synchronized lyrics sheet, and equalizer UI. |

---

## 3. Native Audio Engine & Background Foreground Service Flow

Anni Music delivers gapless playback, lock-screen media controls, Android Auto / Bluetooth AVRCP metadata, audio focus ducking, and headset unplug auto-pause via `just_audio` bridged with `audio_service`.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as Player UI (Riverpod)
    participant Handler as AnniAudioHandler (audio_service)
    participant Player as AudioPlayer (just_audio)
    participant Cache as Offline Cache / Local Storage
    participant Stream as Legal Remote CDN / Backend

    User->>UI: Tap Track ("Midnight Resonance")
    UI->>Handler: playTrack(track, queue)
    Handler->>Cache: existsInOfflineVault(track.id)?
    alt Track Cached Offline or Local Device File
        Cache-->>Handler: Decrypted File URI (file:///...)
        Handler->>Player: setAudioSource(AudioSource.uri(fileUri))
    else Remote Stream with Opportunistic Caching
        Handler->>Player: setAudioSource(LockCachingAudioSource(streamUrl))
        Player->>Stream: HTTP GET (Range: bytes=0-)
        Stream-->>Player: 206 Partial Content (Audio Frames)
    end
    Handler->>Handler: Update MediaItem (Title, Artist, High-Res Artwork)
    Handler-->>UI: Broadcast PlaybackState (playing, position, buffered)
    Player-->>UI: positionStream (60fps smooth progress & LRC line sync)
```

### Audio Features Engineered
- **Gapless Concatenating Queue**: Uses `ConcatenatingAudioSource` so the next track in the queue pre-buffers before the active track finishes.
- **Crossfade & Playback Speed**: Configurable `0s–12s` volume envelope crossfading and `0.5x–2.0x` pitch-preserved tempo control.
- **Sleep Timer**: Countdown timer with gentle 5-second logarithmic volume fade-out before pausing.
- **Android Foreground Service**: Declared with `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permission and `MediaButtonReceiver` so playback survives screen lock and app task swiping.

---

## 4. Cloud Synchronization & Conflict Resolution Pipeline

Users can create playlists, favorite tracks, and listen completely offline. When connectivity is restored, the app executes a **bi-directional delta sync** against `POST /api/v1/sync`.

```mermaid
sequenceDiagram
    autonumber
    participant App as Mobile App (Local Sync Queue)
    participant API as Fastify /api/v1/sync
    participant DB as PostgreSQL 16 (Prisma Transaction)

    App->>App: Collect pending mutations since lastSyncTimestamp
    App->>API: POST /api/v1/sync { lastSyncedAt, playlists[], favorites[], history[] }
    API->>DB: BEGIN TRANSACTION
    API->>DB: Upsert Favorites & Listening History (Idempotent)
    loop Each Client Playlist Mutation
        API->>DB: Compare client.updatedAt vs server.updatedAt
        alt Client Version is Newer (or New Playlist)
            API->>DB: Upsert Playlist & Replace Track Order
        else Server Version is Newer
            API->>API: Retain Server State for Delta Response
        end
    end
    API->>DB: Query all records modified > lastSyncedAt
    API->>DB: COMMIT
    API-->>App: 200 OK { serverTimestamp, delta: { playlists, favorites, history } }
    App->>App: Merge Delta into Local Storage & Update lastSyncedAt
```

---

## 5. Database Entity-Relationship Diagram (PostgreSQL + Prisma)

```mermaid
erDiagram
    USER ||--o{ REFRESH_TOKEN : "owns"
    USER ||--o{ PLAYLIST : "creates"
    USER ||--o{ FAVORITE_TRACK : "likes"
    USER ||--o{ LISTENING_HISTORY : "streams"
    USER ||--o{ UPLOADED_TRACK : "uploads"
    PLAYLIST ||--o{ PLAYLIST_TRACK : "contains"
    TRACK_CATALOG ||--o{ PLAYLIST_TRACK : "referenced_in"
    TRACK_CATALOG ||--o{ FAVORITE_TRACK : "referenced_in"
    TRACK_CATALOG ||--o{ LISTENING_HISTORY : "logged_in"

    USER {
        uuid id PK
        string email UK
        string username UK
        string passwordHash
        string displayName
        string avatarUrl
        jsonb preferences
        datetime createdAt
        datetime updatedAt
    }

    TRACK_CATALOG {
        string id PK "provider:externalId"
        string title
        string artist
        string album
        int durationSeconds
        string artworkUrl
        string streamUrl
        string sourceProvider "AUDIUS | JAMENDO | ARCHIVE | CURATED | USER_UPLOAD"
        string licenseUrl
        string genre
        string mood
        int bpm
        text syncedLyricsLrc
        datetime createdAt
    }

    PLAYLIST {
        uuid id PK
        uuid userId FK
        string name
        string description
        string coverUrl
        boolean isPublic
        int version
        boolean isDeleted
        datetime createdAt
        datetime updatedAt
    }

    PLAYLIST_TRACK {
        uuid id PK
        uuid playlistId FK
        string trackId FK
        int position
        datetime addedAt
    }

    FAVORITE_TRACK {
        uuid id PK
        uuid userId FK
        string trackId FK
        boolean isDeleted
        datetime updatedAt
    }

    LISTENING_HISTORY {
        uuid id PK
        uuid userId FK
        string trackId FK
        int playedDurationSeconds
        boolean completed
        datetime playedAt
    }

    REFRESH_TOKEN {
        uuid id PK
        uuid userId FK
        string tokenHash UK
        datetime expiresAt
        boolean revoked
        datetime createdAt
    }
```

---

## 6. Security & Legal Compliance Architecture

1. **100% Legal Streaming Sources**:
   - **Audius Open Network**: Streams artist-uploaded tracks via official public discovery nodes.
   - **Jamendo Music API**: Streams Creative Commons licensed independent music with full artist & license attribution.
   - **Internet Archive Audio**: Public domain and CC-BY live concerts and studio recordings.
   - **User Personal Cloud Locker**: Users can upload their own DRM-free audio files (`mp3`, `flac`, `m4a`, `wav`, `ogg`) to S3/MinIO storage and stream them back to their own authenticated devices.
2. **Authentication & Authorization**:
   - Passwords hashed with `bcryptjs` (cost factor 12).
   - Short-lived JWT Access Tokens (`15m`) paired with rotating HTTP-only/secure Refresh Tokens (`30d`) stored hashed in PostgreSQL.
3. **Offline Vault Encryption**:
   - Downloaded tracks are stored inside the app's private sandbox directory with SHA-256 integrity verification and metadata indexing.
