# 🎵 Anni Music

> **"Your music. Your world."**
> A flagship, offline-first mobile music streaming & local audio player built with **Flutter (Clean Architecture + Riverpod + `just_audio` + `audio_service`)** and a cloud-native **Fastify + TypeScript + Prisma + PostgreSQL + Redis** backend.

---

## ✨ Key Features

- **🎧 Gapless & Background Audio Engine**: Powered by `just_audio` and `audio_service` with lock-screen media controls, Android Foreground Service notification, Bluetooth/headset button handling, audio focus ducking, crossfade (`0s–12s`), playback speed control (`0.5x–2.0x`), and sleep timer.
- **🌐 100% Legal Multi-Provider Streaming**: Unified search and high-bitrate streaming across **Audius Open Network**, **Jamendo Creative Commons**, **Internet Archive**, **Curated CC Catalogs**, and your personal **Cloud Audio Locker** (upload your own DRM-free tracks).
- **📂 Device-Local Audio Scanner & Player**: Scans and plays local `.mp3`, `.flac`, `.m4a`, `.wav`, and `.ogg` files on your phone with embedded ID3/Vorbis artwork extraction.
- **📴 Offline-First Downloads & Encrypted Vault**: Download legal tracks and playlists for airplane-mode playback with SHA-256 integrity checks and storage management.
- **🎤 Time-Synced LRC Lyrics**: Real-time auto-scrolling synchronized lyrics (`LRCLIB` + embedded LRC parser) with tap-to-seek on any lyric line.
- **☁️ Bi-Directional Cloud Sync**: Offline mutations to playlists, favorites, and listening history automatically synchronize with the cloud backend using Last-Write-Wins delta resolution.
- **🎨 Obsidian Glassmorphic Aesthetic**: Deep obsidian dark theme (`#0A0A0F`) with electric violet (`#7C4DFF`) and neon cyan (`#00E5FF`) accents, dynamic album-art palette extraction, and smooth 60fps micro-animations.

---

## 🗂️ Monorepo Structure

```text
anni-music/
├── app/                          # Flutter Mobile Application (Android & iOS)
│   ├── android/                  # Gradle config, AndroidManifest, Release Keystore signing
│   ├── lib/
│   │   ├── core/                 # Theme, Dio API client, AudioHandler, DI, Storage
│   │   └── features/             # Clean Architecture features (auth, home, search, player, library, lyrics)
│   ├── test/                     # Widget & Unit tests
│   └── pubspec.yaml
├── backend/                      # Node.js 20 + Fastify + TypeScript + Prisma Cloud API
│   ├── prisma/                   # PostgreSQL schema, migrations, and curated CC seed catalog
│   ├── src/
│   │   ├── config/               # Zod environment configuration
│   │   ├── modules/              # Auth, Search, Playlists, Sync, Recommendations, Lyrics, Analytics
│   │   ├── providers/            # Legal Music Providers (Audius, Jamendo, Curated CC, LRCLIB)
│   │   └── server.ts             # Fastify application entrypoint
│   └── package.json
├── infra/                        # Docker & Cloud Deployment Infrastructure
│   ├── Dockerfile                # Multi-stage production Node 20 Alpine image
│   ├── docker-compose.yml        # Full stack: Postgres 16 + Redis 7 + MinIO S3 + Backend API
│   ├── render.yaml               # Render.com one-click cloud blueprint
│   ├── railway.json              # Railway.app deployment manifest
│   ├── fly.toml                  # Fly.io deployment config
│   └── scripts/                  # Release keystore generators (.ps1 & .sh)
├── .github/workflows/            # Automated CI/CD Pipelines
│   ├── ci.yml                    # Push/PR lint, test, and debug APK build
│   └── release.yml               # Tag/Manual signed Release APK + AAB publisher
└── docs/                         # Technical & User Documentation
    ├── ARCHITECTURE.md           # Mermaid system context, audio flow, sync & ER diagrams
    ├── openapi.yaml              # OpenAPI 3.1.0 REST API specification
    └── APK_BUILD_AND_RELEASE_GUIDE.md
```

---

## 🚀 Quickstart: Run Full Stack Locally with Docker

Launch PostgreSQL 16, Redis 7, MinIO S3 object storage, and the Anni Music Backend API with a single command:

```bash
docker compose -f infra/docker-compose.yml up --build -d
```

- **Backend API Base URL**: `http://localhost:4000/api/v1`
- **Health Check Endpoint**: `http://localhost:4000/api/v1/health`
- **MinIO S3 Console**: `http://localhost:9001`

### Run Backend in Local Dev Mode (Without Docker)

```bash
cd backend
cp .env.example .env
npm install
npx prisma generate
npx prisma migrate dev
npm run prisma:seed
npm run dev
```

---

## 📱 Run & Build the Flutter Mobile App

### Run on Connected Android Device or Emulator

```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```
*(Use `http://10.0.2.2:4000/api/v1` for the Android Emulator, or your deployed cloud HTTPS URL such as `https://anni-music-api.onrender.com/api/v1` for a physical phone.)*

### Build a Signed Release APK for Your Phone

1. **Generate a Release Keystore**:
   - **Windows**: `powershell -ExecutionPolicy Bypass -File .\infra\scripts\generate-keystore.ps1`
   - **macOS/Linux**: `./infra/scripts/generate-keystore.sh`
2. **Build the Release APK**:
   ```bash
   cd app
   flutter build apk --release \
     --dart-define=API_BASE_URL=https://anni-music-api.onrender.com/api/v1
   ```
3. **Install on your phone**:
   Find the APK at `app/build/app/outputs/flutter-apk/app-release.apk`, or push a git tag (`git tag v1.0.0 && git push origin v1.0.0`) to have **GitHub Actions** automatically compile and attach `Anni-Music-v1.0.0.apk` to your **GitHub Releases** page!

👉 See the complete [**APK Build, Signing & Phone Installation Guide**](docs/APK_BUILD_AND_RELEASE_GUIDE.md) for step-by-step instructions.

---

## ⚙️ Backend Environment Variables (`backend/.env`)

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `NODE_ENV` | Runtime environment (`development`, `production`, `test`) | `development` |
| `PORT` | HTTP server listening port | `4000` |
| `HOST` | Bind address | `0.0.0.0` |
| `DATABASE_URL` | PostgreSQL 16 connection string | `postgresql://anni:anni_secret_password@localhost:5432/anni_music?schema=public` |
| `REDIS_URL` | Redis 7 connection string (optional, falls back to in-memory cache) | `redis://localhost:6379` |
| `JWT_ACCESS_SECRET` | Secret key for signing 15-minute JWT access tokens | *64-char random hex* |
| `JWT_REFRESH_SECRET` | Secret key for signing 30-day JWT refresh tokens | *64-char random hex* |
| `AUDIUS_APP_NAME` | Application identifier for Audius Open Network API | `AnniMusic` |
| `JAMENDO_CLIENT_ID` | Optional Jamendo API Client ID for expanded CC catalog | *(optional)* |
| `S3_ENDPOINT` | S3 / MinIO endpoint for user audio uploads | `http://localhost:9000` |
| `S3_BUCKET` | Bucket name for media storage | `anni-media` |

---

## 📚 Documentation Index

- 🏛️ [**System Architecture & Mermaid Diagrams (`docs/ARCHITECTURE.md`)**](docs/ARCHITECTURE.md)
- 📜 [**OpenAPI 3.1.0 Specification (`docs/openapi.yaml`)**](docs/openapi.yaml)
- 📲 [**APK Build, Keystore Signing & Android Installation Guide (`docs/APK_BUILD_AND_RELEASE_GUIDE.md`)**](docs/APK_BUILD_AND_RELEASE_GUIDE.md)

---

## ⚖️ Legal & Licensing Compliance

Anni Music strictly streams and caches music from **authorized, legal sources**:
1. **Audius Open Network** (public artist-authorized streams via Audius REST API v1).
2. **Jamendo Music** (Creative Commons licensed independent tracks with full artist attribution).
3. **Curated Creative Commons & Public Domain Audio** (pre-seeded CC-BY / CC0 tracks).
4. **User Personal Cloud Locker & Device Local Files** (users playing their own DRM-free audio files).

No unauthorized scraping or DRM circumvention is used anywhere in this repository.
