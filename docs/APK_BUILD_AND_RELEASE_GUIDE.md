# Anni Music — APK Build, Signing, Cloud Deployment & Phone Installation Guide

This guide walks you step-by-step through deploying the **Anni Music Cloud Backend**, generating a cryptographic **Android Release Keystore**, building a signed **Release `.apk`** (locally or automatically via GitHub Actions), and installing **Anni Music** directly onto your Android phone.

---

## Part 1: Deploy the Public HTTPS Backend (5 Minutes)

So your phone can stream music, search legal catalogs, and sync playlists from anywhere (over Wi-Fi or mobile data), deploy `/backend` to a public HTTPS URL first.

### Option A: One-Click Deploy on Render.com (Free Tier)
1. Push this repository to your GitHub account.
2. Log in to [Render.com](https://render.com) and click **New +** → **Blueprint**.
3. Connect your GitHub repository. Render will automatically detect [`infra/render.yaml`](../infra/render.yaml).
4. Click **Apply**. Render will provision:
   - `anni-music-db` (Managed PostgreSQL 16)
   - `anni-music-redis` (Managed Redis 7)
   - `anni-music-api` (Dockerized Fastify API with automatic Prisma migrations)
5. Once live, copy your public HTTPS URL, e.g.:
   ```text
   https://anni-music-api.onrender.com/api/v1
   ```
6. Verify health in your browser:
   ```text
   https://anni-music-api.onrender.com/api/v1/health
   ```

### Option B: Deploy on Railway.app or Fly.io
- **Railway**: Create a new project from your GitHub repo — Railway reads [`infra/railway.json`](../infra/railway.json) automatically. Add PostgreSQL and Redis plugins, then copy your generated `https://*.up.railway.app/api/v1` domain.
- **Fly.io**:
  ```bash
  fly launch --config infra/fly.toml
  fly postgres create --name anni-music-db
  fly postgres attach anni-music-db
  fly deploy --config infra/fly.toml
  ```

---

## Part 2: Generate Your Android Release Keystore

Android requires all release `.apk` and `.aab` binaries to be cryptographically signed with a `.jks` keystore. We provide automated scripts for both Windows PowerShell and macOS/Linux.

### On Windows (PowerShell)
Run from the root of the repository:
```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\generate-keystore.ps1
```

### On macOS / Linux (Bash)
```bash
chmod +x ./infra/scripts/generate-keystore.sh
./infra/scripts/generate-keystore.sh
```

### What the Script Does Automatically
1. Generates a 2048-bit RSA PKCS12 keystore at `app/android/keystore/anni-release-key.jks` (valid for 10,000 days).
2. Writes `app/android/key.properties` so Gradle automatically signs release builds.
3. Exports a single-line Base64 file at `infra/scripts/anni-release-key.base64.txt` and prints the 4 secret values for GitHub Actions.

> [!IMPORTANT]
> Both `*.jks` and `app/android/key.properties` are protected by `.gitignore` so your private signing keys are never committed to Git.

---

## Part 3: Automated Cloud APK Build & GitHub Release (No Local Android SDK Needed!)

You can let **GitHub Actions** compile and publish your signed `.apk` and `.aab` in the cloud and give you a direct download link for your phone.

### Step 1: (Optional) Configure GitHub Secrets
In your GitHub repository, navigate to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Value |
| :--- | :--- |
| `API_BASE_URL` | Your public backend URL (e.g., `https://anni-music-api.onrender.com/api/v1`) |
| `ANNI_KEYSTORE_BASE64` | Contents of `infra/scripts/anni-release-key.base64.txt` |
| `ANNI_KEYSTORE_PASSWORD` | Password printed by the keystore generator script |
| `ANNI_KEY_PASSWORD` | Key password printed by the keystore generator script |
| `ANNI_KEY_ALIAS` | `anni_release_key` |

*(Note: Even if you skip adding the keystore secrets on a fresh fork, [`.github/workflows/release.yml`](../.github/workflows/release.yml) automatically generates a fallback release keystore on the fly so your build never fails!)*

### Step 2: Trigger a Release via Git Tag or Manual Button

**Method A — Push a Version Tag:**
```bash
git tag v1.0.0
git push origin v1.0.0
```

**Method B — Click "Run workflow" in GitHub UI:**
1. Open your GitHub repository → **Actions** tab.
2. Select **Anni Music Android Release (APK & AAB)** on the left.
3. Click **Run workflow**, enter `v1.0.0` and your `API_BASE_URL`, and click **Run workflow**.

### Step 3: Get Your Public APK Download Link
Once the workflow finishes (~3–5 minutes):
1. Go to your repository's **Releases** page (`https://github.com/<your-username>/<your-repo>/releases/tag/v1.0.0`).
2. Under **Assets**, you will find:
   - **`Anni-Music-v1.0.0.apk`** (Direct Android installer)
   - **`Anni-Music-v1.0.0.aab`** (Google Play Store App Bundle)
   - **`Anni-Music-v1.0.0-SHA256SUMS.txt`** (Cryptographic SHA-256 checksums)
3. Copy the link to `Anni-Music-v1.0.0.apk` or scan the GitHub Release URL on your phone!

---

## Part 4: Build the Signed Release APK Locally (Optional)

If you have the Flutter SDK (3.19+) and Android SDK / JDK 17 installed on your machine:

```bash
# 1. Navigate to the Flutter app directory
cd app

# 2. Fetch packages
flutter pub get

# 3. Build the signed release APK pointing to your cloud backend
flutter build apk --release \
  --dart-define=API_BASE_URL=https://anni-music-api.onrender.com/api/v1
```

Your signed release APK will be output to:
```text
app/build/app/outputs/flutter-apk/app-release.apk
```

To build split-per-ABI APKs (smaller download size for modern 64-bit ARMv8 phones):
```bash
flutter build apk --release --split-per-abi \
  --dart-define=API_BASE_URL=https://anni-music-api.onrender.com/api/v1
```

---

## Part 5: Install Anni Music on Your Android Phone

### Method 1: Over-the-Air Download (Recommended)
1. Open Chrome or any browser on your Android phone and navigate to your **GitHub Releases** page (`https://github.com/<your-username>/<your-repo>/releases/latest`).
2. Tap **`Anni-Music-v1.0.0.apk`** to download the installer.
3. Tap the download notification when complete.
4. If Android displays *"For your security, your phone currently isn't allowed to install unknown apps from this source"*:
   - Tap **Settings** on the prompt.
   - Toggle ON **Allow from this source**.
   - Return and tap **Install**.
5. Tap **Open** to launch **Anni Music**!

### Method 2: Install via USB Debugging (`adb`)
If your phone is connected to your computer via USB with **USB Debugging** enabled:
```bash
adb install -r app/build/app/outputs/flutter-apk/app-release.apk
```

---

## Part 6: First-Time Permissions on Your Phone

When you first open **Anni Music** on Android 13 / 14+:
1. **Notification Permission (`POST_NOTIFICATIONS`)**: Allow notifications so the lock-screen media player controls and background playback notification bar appear.
2. **Audio & Music Access (`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE`)**: Allow audio access in the **Local Files** tab so Anni Music can scan and play `.mp3`, `.flac`, `.m4a`, `.wav`, and `.ogg` songs stored on your device.
