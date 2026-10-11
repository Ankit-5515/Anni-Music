import 'package:equatable/equatable.dart';

/// User audio, equalizer, and appearance settings persisted locally and synced to cloud.
class UserSettingsEntity extends Equatable {
  const UserSettingsEntity({
    this.themeMode = 'dark',
    this.streamingQuality = 'high',
    this.downloadQuality = 'lossless',
    this.crossfadeSeconds = 0,
    this.gaplessPlayback = true,
    this.replayGain = true,
    this.equalizerEnabled = true,
    this.equalizerPreset = 'Signature Cinema',
    this.equalizerBands = const <double>[1.5, 2.5, 1.8, 0.5, -0.3, 0.2, 1.2, 2.0, 2.4, 2.0],
    this.bassBoostStrength = 250,
    this.virtualizerStrength = 200,
    this.wifiOnlyDownloads = false,
    this.analyticsOptIn = true,
    this.offlineMode = false,
  });

  /// `'dark'` (Obsidian `#07070A`), `'amoled'` (`#000000`), or `'light'` (Daylight).
  final String themeMode;

  /// `'low'` (96kbps), `'normal'` (160kbps), `'high'` (320kbps), `'lossless'` (FLAC).
  final String streamingQuality;

  /// `'normal'`, `'high'`, `'lossless'`.
  final String downloadQuality;

  /// Crossfade duration in seconds (0 to 12).
  final int crossfadeSeconds;

  final bool gaplessPlayback;
  final bool replayGain;
  final bool equalizerEnabled;
  final String equalizerPreset;

  /// 10-band gain values in dB (-12.0 to +12.0) for [31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz].
  final List<double> equalizerBands;

  /// Bass boost strength from 0 to 1000.
  final int bassBoostStrength;

  /// Spatial virtualizer strength from 0 to 1000.
  final int virtualizerStrength;

  final bool wifiOnlyDownloads;
  final bool analyticsOptIn;
  final bool offlineMode;

  bool get isAmoled => themeMode.toLowerCase() == 'amoled';
  bool get isLight => themeMode.toLowerCase() == 'light';

  UserSettingsEntity copyWith({
    String? themeMode,
    String? streamingQuality,
    String? downloadQuality,
    int? crossfadeSeconds,
    bool? gaplessPlayback,
    bool? replayGain,
    bool? equalizerEnabled,
    String? equalizerPreset,
    List<double>? equalizerBands,
    int? bassBoostStrength,
    int? virtualizerStrength,
    bool? wifiOnlyDownloads,
    bool? analyticsOptIn,
    bool? offlineMode,
  }) {
    return UserSettingsEntity(
      themeMode: themeMode ?? this.themeMode,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      replayGain: replayGain ?? this.replayGain,
      equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      equalizerBands: equalizerBands ?? this.equalizerBands,
      bassBoostStrength: bassBoostStrength ?? this.bassBoostStrength,
      virtualizerStrength: virtualizerStrength ?? this.virtualizerStrength,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
      offlineMode: offlineMode ?? this.offlineMode,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'themeMode': themeMode,
      'streamingQuality': streamingQuality,
      'downloadQuality': downloadQuality,
      'crossfadeSeconds': crossfadeSeconds,
      'gaplessPlayback': gaplessPlayback,
      'replayGain': replayGain,
      'equalizerEnabled': equalizerEnabled,
      'equalizerPreset': equalizerPreset,
      'equalizerBands': equalizerBands,
      'bassBoostStrength': bassBoostStrength,
      'virtualizerStrength': virtualizerStrength,
      'wifiOnlyDownloads': wifiOnlyDownloads,
      'analyticsOptIn': analyticsOptIn,
      'offlineMode': offlineMode,
    };
  }

  factory UserSettingsEntity.fromJson(Map<String, dynamic> json) {
    final List<double> bands = <double>[];
    final dynamic rawBands = json['equalizerBands'];
    if (rawBands is List && rawBands.length == 10) {
      for (final dynamic item in rawBands) {
        bands.add((item as num?)?.toDouble() ?? 0.0);
      }
    } else {
      bands.addAll(const <double>[1.5, 2.5, 1.8, 0.5, -0.3, 0.2, 1.2, 2.0, 2.4, 2.0]);
    }

    return UserSettingsEntity(
      themeMode: (json['themeMode'] as String?) ?? 'dark',
      streamingQuality: (json['streamingQuality'] as String?) ?? 'high',
      downloadQuality: (json['downloadQuality'] as String?) ?? 'lossless',
      crossfadeSeconds: (json['crossfadeSeconds'] as num?)?.toInt() ?? 0,
      gaplessPlayback: (json['gaplessPlayback'] as bool?) ?? true,
      replayGain: (json['replayGain'] as bool?) ?? true,
      equalizerEnabled: (json['equalizerEnabled'] as bool?) ?? true,
      equalizerPreset: (json['equalizerPreset'] as String?) ?? 'Signature Cinema',
      equalizerBands: bands,
      bassBoostStrength: (json['bassBoostStrength'] as num?)?.toInt() ?? 250,
      virtualizerStrength: (json['virtualizerStrength'] as num?)?.toInt() ?? 200,
      wifiOnlyDownloads: (json['wifiOnlyDownloads'] as bool?) ?? false,
      analyticsOptIn: (json['analyticsOptIn'] as bool?) ?? true,
      offlineMode: (json['offlineMode'] as bool?) ?? false,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        themeMode,
        streamingQuality,
        downloadQuality,
        crossfadeSeconds,
        gaplessPlayback,
        replayGain,
        equalizerEnabled,
        equalizerPreset,
        equalizerBands,
        bassBoostStrength,
        virtualizerStrength,
        wifiOnlyDownloads,
        analyticsOptIn,
        offlineMode,
      ];
}

/// Authenticated or guest user profile entity.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isGuest = false,
    this.settings = const UserSettingsEntity(),
    this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isGuest;
  final UserSettingsEntity settings;
  final DateTime? createdAt;

  factory UserProfile.guest() {
    return const UserProfile(
      id: 'guest_local_user',
      email: 'guest@anni.music',
      displayName: 'Music Explorer',
      isGuest: true,
    );
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isGuest,
    UserSettingsEntity? settings,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuest: isGuest ?? this.isGuest,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'isGuest': isGuest,
      'settings': settings.toJson(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? rawSettings =
        json['settings'] is Map<String, dynamic> ? json['settings'] as Map<String, dynamic> : null;

    return UserProfile(
      id: (json['id'] as String?) ?? 'guest_local_user',
      email: (json['email'] as String?) ?? 'guest@anni.music',
      displayName: (json['displayName'] as String?) ?? 'Music Explorer',
      avatarUrl: json['avatarUrl'] as String?,
      isGuest: (json['isGuest'] as bool?) ?? false,
      settings: rawSettings != null
          ? UserSettingsEntity.fromJson(rawSettings)
          : const UserSettingsEntity(),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        email,
        displayName,
        avatarUrl,
        isGuest,
        settings,
        createdAt,
      ];
}
