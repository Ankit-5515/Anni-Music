import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Legal and local audio sources supported by Anni Music.
enum TrackSource {
  local,
  jamendo,
  internetArchive,
  youtube;

  String get value {
    switch (this) {
      case TrackSource.local:
        return 'local';
      case TrackSource.jamendo:
        return 'jamendo';
      case TrackSource.internetArchive:
        return 'internet_archive';
      case TrackSource.youtube:
        return 'youtube';
    }
  }

  String get displayName {
    switch (this) {
      case TrackSource.local:
        return 'On Device';
      case TrackSource.jamendo:
        return 'Jamendo CC';
      case TrackSource.internetArchive:
        return 'Internet Archive';
      case TrackSource.youtube:
        return 'YouTube IFrame';
    }
  }

  static TrackSource fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'local':
        return TrackSource.local;
      case 'jamendo':
        return TrackSource.jamendo;
      case 'internet_archive':
      case 'internetarchive':
      case 'archive':
        return TrackSource.internetArchive;
      case 'youtube':
      case 'yt':
        return TrackSource.youtube;
      default:
        return TrackSource.jamendo;
    }
  }
}

/// Core immutable Track entity representing either a local audio file or a legal streaming track.
class Track extends Equatable {
  const Track({
    required this.id,
    required this.source,
    required this.externalId,
    required this.title,
    required this.artist,
    this.album = 'Unknown Album',
    this.genre = 'Indie',
    this.durationSeconds = 0,
    this.artworkUrl,
    this.localFilePath,
    this.streamUrl,
    this.downloadUrl,
    this.qualityBadge = '320kbps',
    this.license = 'CC-BY',
    this.releaseYear,
    this.waveform = const <double>[],
    this.dominantColor = '#8B5CF6',
    this.isFavorite = false,
    this.isDownloaded = false,
    this.replayGainDb = 0.0,
  });

  final String id;
  final TrackSource source;
  final String externalId;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int durationSeconds;
  final String? artworkUrl;
  final String? localFilePath;
  final String? streamUrl;
  final String? downloadUrl;
  final String qualityBadge;
  final String license;
  final int? releaseYear;
  final List<double> waveform;
  final String dominantColor;
  final bool isFavorite;
  final bool isDownloaded;
  final double replayGainDb;

  Duration get duration => Duration(seconds: durationSeconds);

  bool get isLocal => source == TrackSource.local;

  bool get isYouTube => source == TrackSource.youtube;

  bool get isPlayableOffline =>
      isLocal || (isDownloaded && localFilePath != null && localFilePath!.isNotEmpty);

  bool get canDownload =>
      (source == TrackSource.jamendo || source == TrackSource.internetArchive) &&
      (downloadUrl != null || streamUrl != null);

  String? get effectivePlayableUrl {
    if (localFilePath != null && localFilePath!.isNotEmpty) {
      return localFilePath;
    }
    return streamUrl ?? downloadUrl;
  }

  String get formattedDuration {
    final int totalSec = math.max(0, durationSeconds);
    final int minutes = totalSec ~/ 60;
    final int seconds = totalSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Generates a deterministic 48-bar normalized waveform if none was supplied by the source.
  List<double> get effectiveWaveform {
    if (waveform.isNotEmpty) return waveform;
    final int seed = id.codeUnits.fold<int>(0, (int prev, int elem) => prev + elem);
    final math.Random rng = math.Random(seed);
    return List<double>.generate(48, (int i) {
      final double envelope = math.sin((i / 48.0) * math.pi);
      final double jitter = 0.25 + (rng.nextDouble() * 0.75);
      return (0.18 + (envelope * jitter * 0.82)).clamp(0.15, 1.0);
    });
  }

  Track copyWith({
    String? id,
    TrackSource? source,
    String? externalId,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? durationSeconds,
    String? artworkUrl,
    String? localFilePath,
    String? streamUrl,
    String? downloadUrl,
    String? qualityBadge,
    String? license,
    int? releaseYear,
    List<double>? waveform,
    String? dominantColor,
    bool? isFavorite,
    bool? isDownloaded,
    double? replayGainDb,
  }) {
    return Track(
      id: id ?? this.id,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      streamUrl: streamUrl ?? this.streamUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      qualityBadge: qualityBadge ?? this.qualityBadge,
      license: license ?? this.license,
      releaseYear: releaseYear ?? this.releaseYear,
      waveform: waveform ?? this.waveform,
      dominantColor: dominantColor ?? this.dominantColor,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      replayGainDb: replayGainDb ?? this.replayGainDb,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'source': source.value,
      'externalId': externalId,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'durationSeconds': durationSeconds,
      'artworkUrl': artworkUrl,
      'localFilePath': localFilePath,
      'streamUrl': streamUrl,
      'downloadUrl': downloadUrl,
      'qualityBadge': qualityBadge,
      'license': license,
      'releaseYear': releaseYear,
      'waveform': waveform,
      'dominantColor': dominantColor,
      'isFavorite': isFavorite,
      'isDownloaded': isDownloaded,
      'replayGainDb': replayGainDb,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final List<double> parsedWaveform = <double>[];
    final dynamic rawWaveform = json['waveform'];
    if (rawWaveform is List) {
      for (final dynamic item in rawWaveform) {
        if (item is num) {
          parsedWaveform.add(item.toDouble().clamp(0.05, 1.0));
        }
      }
    }

    return Track(
      id: (json['id'] as String?) ??
          '${json['source'] ?? 'jamendo'}_${json['externalId'] ?? DateTime.now().millisecondsSinceEpoch}',
      source: TrackSource.fromString(json['source'] as String?),
      externalId: (json['externalId'] ?? json['id'] ?? '').toString(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Untitled Track',
      artist: (json['artist'] as String?)?.trim().isNotEmpty == true
          ? (json['artist'] as String).trim()
          : 'Unknown Artist',
      album: (json['album'] as String?)?.trim().isNotEmpty == true
          ? (json['album'] as String).trim()
          : 'Single',
      genre: (json['genre'] as String?)?.trim().isNotEmpty == true
          ? (json['genre'] as String).trim()
          : 'Indie',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ??
          (json['duration'] as num?)?.toInt() ??
          0,
      artworkUrl: json['artworkUrl'] as String?,
      localFilePath: json['localFilePath'] as String?,
      streamUrl: json['streamUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      qualityBadge: (json['qualityBadge'] as String?) ?? '320kbps',
      license: (json['license'] as String?) ?? 'CC-BY',
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      waveform: parsedWaveform,
      dominantColor: (json['dominantColor'] as String?) ?? '#8B5CF6',
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      isDownloaded: (json['isDownloaded'] as bool?) ?? false,
      replayGainDb: (json['replayGainDb'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        source,
        externalId,
        title,
        artist,
        album,
        genre,
        durationSeconds,
        artworkUrl,
        localFilePath,
        streamUrl,
        downloadUrl,
        qualityBadge,
        license,
        releaseYear,
        waveform,
        dominantColor,
        isFavorite,
        isDownloaded,
        replayGainDb,
      ];
}
