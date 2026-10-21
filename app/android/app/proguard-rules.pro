# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Anni Music Native Entry Points & Widget
-keep class com.anni.music.** { *; }

# Audio Service & Just Audio & ExoPlayer
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# On Audio Query
-keep class com.lucasjosino.on_audio_query.** { *; }

# Drift / SQLite3 Native JNA / FFI
-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-dontwarn java.awt.**

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# Ignore unresolved references in transitive packages during R8 minification
-dontwarn **

