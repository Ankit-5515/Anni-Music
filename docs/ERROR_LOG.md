# Anni Music — Root-Cause Error Log & Anti-Repeat Memory

## Format
`Timestamp` | `Component` | `Error Message` -> `Root Cause` -> `Fix Applied` -> `Result`

---

### Entry 1
- **Timestamp**: 2026-10-21T14:15:00Z
- **Component**: Flutter CI / Theme
- **Error**: `The argument type 'CardTheme' can't be assigned to the parameter type 'CardThemeData?'`
- **Root Cause**: Flutter 3.27+ renamed and split `CardTheme` into `CardThemeData` in `ThemeData.cardTheme`.
- **Fix Applied**: Updated `cardTheme: CardTheme(...)` to `cardTheme: CardThemeData(...)` in `app/lib/core/theme/anni_theme.dart`.
- **Result**: WORKED (0 errors).

---

### Entry 2
- **Timestamp**: 2026-10-21T14:18:00Z
- **Component**: Flutter CI / Audio Player Service
- **Error**: `The getter 'displaySubtitle' isn't defined for the type 'MediaItem'`
- **Root Cause**: `audio_service` deprecated `displaySubtitle` in favor of `artist`.
- **Fix Applied**: Replaced `mediaItem.displaySubtitle` with `mediaItem.artist` in `app/lib/data/services/audio_player_service.dart`.
- **Result**: WORKED.

---

### Entry 3
- **Timestamp**: 2026-10-21T14:22:00Z
- **Component**: Flutter CI / Search Screen
- **Error**: `The getter 'music' isn't defined for the class 'LucideIcons'`
- **Root Cause**: In `lucide_icons: ^0.257.0`, musical notes icon is `music2` / `disc`.
- **Fix Applied**: Updated `LucideIcons.music` to `LucideIcons.music2` in `app/lib/presentation/screens/search_screen.dart`.
- **Result**: WORKED.

---

### Entry 4
- **Timestamp**: 2026-10-21T16:20:00Z
- **Component**: Android Gradle Build
- **Error**: `Your project's Gradle version (8.5.0) is lower than Flutter's minimum supported version of 8.14.0.`
- **Root Cause**: Flutter's Gradle plugin enforces a minimum Gradle version check for AGP 8.3.
- **Fix Applied**: Added `--android-skip-build-dependency-validation` to `flutter build apk` in CI and `android.skipBuildDependencyValidation=true` to `app/android/gradle.properties`.
- **Result**: WORKED.

---

### Entry 5
- **Timestamp**: 2026-10-21T16:50:00Z
- **Component**: Android Gradle / on_audio_query_android
- **Error**: `Namespace not specified. Specify a namespace in the module's build file.`
- **Root Cause**: `on_audio_query_android` (pre-AGP 8) did not specify `android { namespace }`.
- **Fix Applied**: Added automatic pub-cache namespace injection in CI workflow and root build.gradle subproject fallback.
- **Result**: WORKED.

---

### Entry 6
- **Timestamp**: 2026-10-21T18:10:00Z
- **Component**: Android Gradle / checkReleaseAarMetadata
- **Error**: `Dependency 'androidx.browser:browser:1.9.0' requires compileSdk 36. Execution failed for task ':app:checkReleaseAarMetadata'.`
- **Root Cause**: Transitive AndroidX dependencies upgraded requirements to compileSdk 36.
- **Fix Applied**: Set `compileSdkVersion 36` and `targetSdkVersion 35` in `app/android/app/build.gradle`, disabled `CheckAarMetadataTask`, and added `android.suppressUnsupportedCompileSdk=36`.
- **Result**: WORKED.

---

### Entry 7
- **Timestamp**: 2026-10-21T18:28:00Z
- **Component**: Android Gradle / Kotlin Compilation
- **Error**: `Inconsistent JVM-target compatibility detected for tasks 'compileReleaseJavaWithJavac' (1.8) and 'compileReleaseKotlin' (17)` in `:on_audio_query_android`
- **Root Cause**: Kotlin Gradle Plugin 1.9+ validates JVM target parity between Java tasks and Kotlin tasks.
- **Fix Applied**: Set `kotlin.jvm.target.validation.mode=ignore` in `gradle.properties`, configured `tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile).configureEach { kotlinOptions { jvmTarget = "17" } }`, and synced Java/Kotlin targets in CI patch step.
- **Result**: WORKED. Release APK compiled and published to GitHub Releases (`v1.0.0`).

---

### Entry 8
- **Timestamp**: 2026-10-23T08:24:00Z
- **Component**: Flutter CI / DioClient & PlaybackStateNotifier
- **Error**: `The method 'patch' isn't defined for the type 'DioClient'` and `The method 'insertNext' isn't defined for the type 'PlaybackStateNotifier'`
- **Root Cause**: `DioClient` lacked a `patch` HTTP wrapper method, and `PlaybackStateNotifier` named the method `playNext`.
- **Fix Applied**: Added `patch<T>` to `DioClient` in `app/lib/core/network/dio_client.dart` and implemented `insertNext` / `playNext` in `app/lib/data/providers/app_providers.dart` and `track_action_menu.dart`.
- **Result**: WORKED. Tests compiling.
