import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Sealed hierarchy of typed domain/data failures across Anni Music.
sealed class AppFailure implements Exception {
  const AppFailure({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final String? code;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppFailure(code: $code, message: $message)';
}

/// Network or API transport failure (timeouts, offline, 5xx errors).
final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    required super.message,
    super.code = 'NETWORK_ERROR',
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

/// Authentication / Authorization failure (401/403, expired session, invalid credentials).
final class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.message,
    super.code = 'AUTH_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Local storage / SQLite / File system failure.
final class StorageFailure extends AppFailure {
  const StorageFailure({
    required super.message,
    super.code = 'STORAGE_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// OS Permission denied failure (e.g., READ_MEDIA_AUDIO or WRITE_SETTINGS).
final class PermissionFailure extends AppFailure {
  const PermissionFailure({
    required super.message,
    super.code = 'PERMISSION_DENIED',
    super.cause,
    super.stackTrace,
  });
}

/// Audio playback, decoding, or stream resolution failure.
final class AudioPlaybackFailure extends AppFailure {
  const AudioPlaybackFailure({
    required super.message,
    super.code = 'AUDIO_PLAYBACK_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Validation failure for user input or malformed metadata.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    super.cause,
    super.stackTrace,
  });
}

/// Centralized structured error logger with ring-buffer history for diagnostics.
class AppLogger {
  AppLogger._();

  static final List<String> _recentLogs = <String>[];
  static const int _maxLogs = 200;

  static List<String> get recentLogs => List<String>.unmodifiable(_recentLogs);

  static void info(String message, {String tag = 'AnniMusic'}) {
    final String entry = '[${DateTime.now().toIso8601String()}] [INFO] [$tag] $message';
    _appendLog(entry);
    if (kDebugMode) {
      developer.log(message, name: tag, level: 800);
    }
  }

  static void warn(String message, {String tag = 'AnniMusic', Object? error}) {
    final String entry =
        '[${DateTime.now().toIso8601String()}] [WARN] [$tag] $message ${error != null ? "| $error" : ""}';
    _appendLog(entry);
    if (kDebugMode) {
      developer.log(message, name: tag, level: 900, error: error);
    }
  }

  static void error(
    String message, {
    String tag = 'AnniMusic',
    Object? error,
    StackTrace? stackTrace,
  }) {
    final String entry =
        '[${DateTime.now().toIso8601String()}] [ERROR] [$tag] $message ${error != null ? "| $error" : ""}';
    _appendLog(entry);
    if (kDebugMode) {
      developer.log(
        message,
        name: tag,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _appendLog(String entry) {
    _recentLogs.add(entry);
    if (_recentLogs.length > _maxLogs) {
      _recentLogs.removeAt(0);
    }
  }
}
