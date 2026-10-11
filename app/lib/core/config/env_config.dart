/// Environment configuration and global application constants for Anni Music.
class EnvConfig {
  const EnvConfig._();

  static const String appName = 'Anni Music';
  static const String tagline = 'Your music. Your world.';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.anni.music';
  static const String nativeAudioChannel = 'com.anni.music/native_audio';

  /// Base URL of the Anni Music Fastify API Gateway.
  /// Override at compile time via `--dart-define=API_BASE_URL=...`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://anni-music-api.onrender.com/api/v1',
  );

  /// Public Jamendo Client ID for direct fallback legal CC catalog queries if offline/serverless.
  static const String jamendoClientId = String.fromEnvironment(
    'JAMENDO_CLIENT_ID',
    defaultValue: '56d30c95',
  );

  /// Whether privacy-safe telemetry is enabled by default.
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: true,
  );

  /// Connect timeout for HTTP requests.
  static const Duration connectTimeout = Duration(seconds: 12);

  /// Receive timeout for HTTP requests.
  static const Duration receiveTimeout = Duration(seconds: 20);
}
