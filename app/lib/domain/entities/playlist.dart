import 'package:equatable/equatable.dart';
import 'track.dart';

/// Immutable Playlist entity supporting both local and cloud-synced playlists,
/// plus `.m3u` / `.m3u8` export and import helpers.
class Playlist extends Equatable {
  const Playlist({
    required this.id,
    required this.name,
    this.description = '',
    this.coverUrl,
    this.isPublic = false,
    this.shareSlug,
    this.tracks = const <Track>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String? coverUrl;
  final bool isPublic;
  final String? shareSlug;
  final List<Track> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get trackCount => tracks.length;

  int get totalDurationSeconds =>
      tracks.fold<int>(0, (int sum, Track item) => sum + item.durationSeconds);

  String get formattedTotalDuration {
    final int totalMinutes = totalDurationSeconds ~/ 60;
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }
    final int hours = totalMinutes ~/ 60;
    final int mins = totalMinutes % 60;
    return '${hours}h ${mins}m';
  }

  String? get effectiveCoverUrl {
    if (coverUrl != null && coverUrl!.isNotEmpty) return coverUrl;
    for (final Track t in tracks) {
      if (t.artworkUrl != null && t.artworkUrl!.isNotEmpty) {
        return t.artworkUrl;
      }
    }
    return null;
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    bool? isPublic,
    String? shareSlug,
    List<Track>? tracks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      isPublic: isPublic ?? this.isPublic,
      shareSlug: shareSlug ?? this.shareSlug,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'coverUrl': coverUrl,
      'isPublic': isPublic,
      'shareSlug': shareSlug,
      'tracks': tracks.map((Track t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final List<Track> parsedTracks = <Track>[];
    final dynamic rawTracks = json['tracks'];
    if (rawTracks is List) {
      for (final dynamic item in rawTracks) {
        if (item is Map<String, dynamic>) {
          if (item['track'] is Map<String, dynamic>) {
            parsedTracks.add(Track.fromJson(item['track'] as Map<String, dynamic>));
          } else {
            parsedTracks.add(Track.fromJson(item));
          }
        }
      }
    }

    return Playlist(
      id: (json['id'] as String?) ?? 'playlist_${DateTime.now().millisecondsSinceEpoch}',
      name: (json['name'] as String?) ?? 'Untitled Playlist',
      description: (json['description'] as String?) ?? '',
      coverUrl: json['coverUrl'] as String?,
      isPublic: (json['isPublic'] as bool?) ?? false,
      shareSlug: json['shareSlug'] as String?,
      tracks: parsedTracks,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  /// Generates standard Extended M3U (`.m3u8`) content for this playlist.
  String toM3u() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:$name');
    for (final Track track in tracks) {
      final int secs = track.durationSeconds > 0 ? track.durationSeconds : -1;
      buffer.writeln('#EXTINF:$secs,${track.artist} - ${track.title}');
      final String location =
          track.localFilePath ?? track.streamUrl ?? track.downloadUrl ?? 'anni://track/${track.id}';
      buffer.writeln(location);
    }
    return buffer.toString();
  }

  /// Parses an Extended M3U (`.m3u` / `.m3u8`) file string into a [Playlist] entity,
  /// matching against existing [knownTracks] where possible or creating local/stream entries.
  static Playlist fromM3u({
    required String m3uContent,
    required String fallbackName,
    List<Track> knownTracks = const <Track>[],
  }) {
    final List<String> lines = m3uContent.split(RegExp(r'\r?\n'));
    String playlistName = fallbackName;
    final List<Track> resolvedTracks = <Track>[];

    String? pendingArtist;
    String? pendingTitle;
    int pendingDuration = 0;

    final Map<String, Track> byPath = <String, Track>{};
    final Map<String, Track> byId = <String, Track>{};
    for (final Track t in knownTracks) {
      byId[t.id] = t;
      if (t.localFilePath != null) {
        byPath[t.localFilePath!] = t;
      }
      if (t.streamUrl != null) {
        byPath[t.streamUrl!] = t;
      }
    }

    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#PLAYLIST:')) {
        final String extracted = line.substring('#PLAYLIST:'.length).trim();
        if (extracted.isNotEmpty) {
          playlistName = extracted;
        }
      } else if (line.startsWith('#EXTINF:')) {
        final String meta = line.substring('#EXTINF:'.length);
        final int commaIdx = meta.indexOf(',');
        if (commaIdx != -1) {
          pendingDuration = int.tryParse(meta.substring(0, commaIdx).trim()) ?? 0;
          if (pendingDuration < 0) pendingDuration = 0;
          final String display = meta.substring(commaIdx + 1).trim();
          final int dashIdx = display.indexOf(' - ');
          if (dashIdx != -1) {
            pendingArtist = display.substring(0, dashIdx).trim();
            pendingTitle = display.substring(dashIdx + 3).trim();
          } else {
            pendingArtist = 'Unknown Artist';
            pendingTitle = display;
          }
        }
      } else if (!line.startsWith('#')) {
        if (line.startsWith('anni://track/')) {
          final String id = line.substring('anni://track/'.length).trim();
          if (byId.containsKey(id)) {
            resolvedTracks.add(byId[id]!);
            pendingArtist = null;
            pendingTitle = null;
            continue;
          }
        }

        if (byPath.containsKey(line)) {
          resolvedTracks.add(byPath[line]!);
        } else {
          final bool isHttp = line.startsWith('http://') || line.startsWith('https://');
          final String id = 'm3u_${line.hashCode.abs()}';
          resolvedTracks.add(
            Track(
              id: id,
              source: isHttp ? TrackSource.jamendo : TrackSource.local,
              externalId: id,
              title: pendingTitle ?? line.split(RegExp(r'[/\\]')).last,
              artist: pendingArtist ?? 'Unknown Artist',
              durationSeconds: pendingDuration,
              localFilePath: isHttp ? null : line,
              streamUrl: isHttp ? line : null,
              qualityBadge: isHttp ? 'STREAM' : 'LOCAL',
            ),
          );
        }
        pendingArtist = null;
        pendingTitle = null;
        pendingDuration = 0;
      }
    }

    final DateTime now = DateTime.now();
    return Playlist(
      id: 'pl_${now.millisecondsSinceEpoch}',
      name: playlistName,
      description: 'Imported from M3U playlist',
      tracks: resolvedTracks,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        description,
        coverUrl,
        isPublic,
        shareSlug,
        tracks,
        createdAt,
        updatedAt,
      ];
}
