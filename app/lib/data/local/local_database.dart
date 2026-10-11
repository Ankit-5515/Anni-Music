import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/error/app_failure.dart';
import '../../domain/entities/download_task_item.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/music_repository.dart';

/// Persisted snapshot of the active playback queue and transport state so Anni Music
/// can resume the exact song and millisecond position after an app restart.
class SavedPlaybackQueueState {
  const SavedPlaybackQueueState({
    this.queue = const <Track>[],
    this.currentIndex = 0,
    this.positionMs = 0,
    this.shuffleEnabled = false,
    this.repeatMode = 'off',
    this.playbackSpeed = 1.0,
  });

  final List<Track> queue;
  final int currentIndex;
  final int positionMs;
  final bool shuffleEnabled;
  final String repeatMode;
  final double playbackSpeed;

  Track? get currentTrack =>
      (currentIndex >= 0 && currentIndex < queue.length) ? queue[currentIndex] : null;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'queue': queue.map((Track t) => t.toJson()).toList(),
      'currentIndex': currentIndex,
      'positionMs': positionMs,
      'shuffleEnabled': shuffleEnabled,
      'repeatMode': repeatMode,
      'playbackSpeed': playbackSpeed,
    };
  }

  factory SavedPlaybackQueueState.fromJson(Map<String, dynamic> json) {
    final List<Track> parsedQueue = <Track>[];
    final dynamic rawQueue = json['queue'];
    if (rawQueue is List) {
      for (final dynamic item in rawQueue) {
        if (item is Map<String, dynamic>) {
          parsedQueue.add(Track.fromJson(item));
        }
      }
    }

    return SavedPlaybackQueueState(
      queue: parsedQueue,
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      shuffleEnabled: (json['shuffleEnabled'] as bool?) ?? false,
      repeatMode: (json['repeatMode'] as String?) ?? 'off',
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Record of a track play event stored locally for history, "Recently Played", and recommendations.
class PlayHistoryEntry {
  const PlayHistoryEntry({
    required this.track,
    required this.playedAt,
    required this.playedSeconds,
  });

  final Track track;
  final DateTime playedAt;
  final int playedSeconds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'track': track.toJson(),
        'playedAt': playedAt.toIso8601String(),
        'playedSeconds': playedSeconds,
      };

  factory PlayHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PlayHistoryEntry(
      track: Track.fromJson(
        (json['track'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      playedAt: DateTime.tryParse((json['playedAt'] as String?) ?? '') ?? DateTime.now(),
      playedSeconds: (json['playedSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// High-performance local persistence engine managing:
/// - Indexed local songs (supports 10,000+ tracks with instant search, A-Z grouping, and multi-field sorting)
/// - Playlists (local & synced)
/// - Favorites
/// - Play history & recently played
/// - Download task states
/// - User settings & saved playback queue state
class LocalDatabase {
  LocalDatabase();

  bool _initialized = false;
  Directory? _storageDir;
  Timer? _flushDebounceTimer;

  // High-speed in-memory indexed stores backed by atomic disk persistence
  final Map<String, Track> _localTracksById = <String, Track>{};
  final Map<String, DateTime> _localTrackAddedAt = <String, DateTime>{};
  final Map<String, Playlist> _playlistsById = <String, Playlist>{};
  final Map<String, Track> _favoritesById = <String, Track>{};
  final List<PlayHistoryEntry> _playHistory = <PlayHistoryEntry>[];
  final Map<String, DownloadTaskItem> _downloadsByTrackId = <String, DownloadTaskItem>{};

  UserSettingsEntity _userSettings = const UserSettingsEntity();
  SavedPlaybackQueueState _savedPlaybackQueue = const SavedPlaybackQueueState();
  DateTime? _lastSyncTimestamp;

  bool get isInitialized => _initialized;
  DateTime? get lastSyncTimestamp => _lastSyncTimestamp;

  /// Initializes the local database and hydrates all indexed collections from disk.
  Future<void> initialize({String? customDirectoryPath}) async {
    if (_initialized) return;

    try {
      if (customDirectoryPath != null) {
        _storageDir = Directory(customDirectoryPath);
      } else {
        final Directory appDocDir = await getApplicationSupportDirectory();
        _storageDir = Directory(p.join(appDocDir.path, 'anni_music_db'));
      }

      if (!_storageDir!.existsSync()) {
        await _storageDir!.create(recursive: true);
      }

      await _loadFromDisk();
      _initialized = true;
    } catch (e) {
      // Fallback to in-memory mode if running in headless test environment without path_provider
      AppLogger.warn('LocalDatabase running in memory-only mode', error: e);
      _initialized = true;
    }
  }

  Future<void> _loadFromDisk() async {
    if (_storageDir == null) return;
    final File dbFile = File(p.join(_storageDir!.path, 'anni_store_v1.json'));
    if (!dbFile.existsSync()) return;

    try {
      final String content = await dbFile.readAsString();
      if (content.trim().isEmpty) return;
      final Map<String, dynamic> root = jsonDecode(content) as Map<String, dynamic>;

      // 1. Local Tracks
      final dynamic rawLocal = root['localTracks'];
      if (rawLocal is List) {
        for (final dynamic item in rawLocal) {
          if (item is Map<String, dynamic>) {
            final Track track = Track.fromJson(item);
            _localTracksById[track.id] = track;
            _localTrackAddedAt[track.id] =
                DateTime.tryParse((item['_addedAt'] as String?) ?? '') ?? DateTime.now();
          }
        }
      }

      // 2. Favorites
      final dynamic rawFavorites = root['favorites'];
      if (rawFavorites is List) {
        for (final dynamic item in rawFavorites) {
          if (item is Map<String, dynamic>) {
            final Track track = Track.fromJson(item).copyWith(isFavorite: true);
            _favoritesById[track.id] = track;
            if (_localTracksById.containsKey(track.id)) {
              _localTracksById[track.id] = _localTracksById[track.id]!.copyWith(isFavorite: true);
            }
          }
        }
      }

      // 3. Playlists
      final dynamic rawPlaylists = root['playlists'];
      if (rawPlaylists is List) {
        for (final dynamic item in rawPlaylists) {
          if (item is Map<String, dynamic>) {
            final Playlist pl = Playlist.fromJson(item);
            _playlistsById[pl.id] = pl;
          }
        }
      }

      // 4. Play History
      final dynamic rawHistory = root['playHistory'];
      if (rawHistory is List) {
        for (final dynamic item in rawHistory) {
          if (item is Map<String, dynamic>) {
            _playHistory.add(PlayHistoryEntry.fromJson(item));
          }
        }
      }

      // 5. Downloads
      final dynamic rawDownloads = root['downloads'];
      if (rawDownloads is List) {
        for (final dynamic item in rawDownloads) {
          if (item is Map<String, dynamic>) {
            final DownloadTaskItem task = DownloadTaskItem.fromJson(item);
            _downloadsByTrackId[task.track.id] = task;
          }
        }
      }

      // 6. Settings
      if (root['userSettings'] is Map<String, dynamic>) {
        _userSettings = UserSettingsEntity.fromJson(root['userSettings'] as Map<String, dynamic>);
      }

      // 7. Saved Playback Queue
      if (root['savedPlaybackQueue'] is Map<String, dynamic>) {
        _savedPlaybackQueue = SavedPlaybackQueueState.fromJson(
          root['savedPlaybackQueue'] as Map<String, dynamic>,
        );
      }

      // 8. Last Sync Timestamp
      if (root['lastSyncTimestamp'] is String) {
        _lastSyncTimestamp = DateTime.tryParse(root['lastSyncTimestamp'] as String);
      }
    } catch (e, st) {
      AppLogger.error('Error hydrating LocalDatabase from disk', error: e, stackTrace: st);
    }
  }

  void _schedulePersist() {
    if (_storageDir == null) return;
    _flushDebounceTimer?.cancel();
    _flushDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      unawaited(flushToDisk());
    });
  }

  /// Immediately writes all in-memory tables atomically to disk.
  Future<void> flushToDisk() async {
    if (_storageDir == null) return;
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'localTracks': _localTracksById.values.map((Track t) {
          final Map<String, dynamic> json = t.toJson();
          json['_addedAt'] = (_localTrackAddedAt[t.id] ?? DateTime.now()).toIso8601String();
          return json;
        }).toList(),
        'favorites': _favoritesById.values.map((Track t) => t.toJson()).toList(),
        'playlists': _playlistsById.values.map((Playlist p) => p.toJson()).toList(),
        'playHistory': _playHistory.take(500).map((PlayHistoryEntry e) => e.toJson()).toList(),
        'downloads': _downloadsByTrackId.values.map((DownloadTaskItem d) => d.toJson()).toList(),
        'userSettings': _userSettings.toJson(),
        'savedPlaybackQueue': _savedPlaybackQueue.toJson(),
        'lastSyncTimestamp': _lastSyncTimestamp?.toIso8601String(),
      };

      final File tempFile = File(p.join(_storageDir!.path, 'anni_store_v1.tmp'));
      final File targetFile = File(p.join(_storageDir!.path, 'anni_store_v1.json'));
      await tempFile.writeAsString(jsonEncode(payload), flush: true);
      await tempFile.rename(targetFile.path);
    } catch (e) {
      AppLogger.warn('Failed flushing LocalDatabase to disk', error: e);
    }
  }

  // ===========================================================================
  // LOCAL LIBRARY TRACKS (10,000+ Indexed Search, Sort, & A-Z Grouping)
  // ===========================================================================

  Future<void> upsertLocalTracks(List<Track> tracks) async {
    final DateTime now = DateTime.now();
    for (final Track track in tracks) {
      final bool isFav = _favoritesById.containsKey(track.id) || track.isFavorite;
      final Track normalized = track.copyWith(isFavorite: isFav);
      _localTracksById[normalized.id] = normalized;
      _localTrackAddedAt.putIfAbsent(normalized.id, () => now);
      if (isFav) {
        _favoritesById[normalized.id] = normalized;
      }
    }
    _schedulePersist();
  }

  Future<void> upsertLocalTrack(Track track) async {
    await upsertLocalTracks(<Track>[track]);
  }

  Future<void> removeLocalTrack(String trackId) async {
    _localTracksById.remove(trackId);
    _localTrackAddedAt.remove(trackId);
    _schedulePersist();
  }

  /// Queries local tracks with instant substring filtering and multi-field sorting.
  List<Track> queryLocalTracks({
    LocalLibrarySortField sortBy = LocalLibrarySortField.title,
    bool ascending = true,
    String? searchQuery,
    String? artistFilter,
    String? albumFilter,
    String? folderFilter,
  }) {
    final String? q = searchQuery?.trim().toLowerCase();
    Iterable<Track> results = _localTracksById.values;

    if (q != null && q.isNotEmpty) {
      results = results.where((Track t) {
        return t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            t.album.toLowerCase().contains(q) ||
            t.genre.toLowerCase().contains(q);
      });
    }

    if (artistFilter != null && artistFilter.isNotEmpty) {
      final String target = artistFilter.toLowerCase();
      results = results.where((Track t) => t.artist.toLowerCase() == target);
    }

    if (albumFilter != null && albumFilter.isNotEmpty) {
      final String target = albumFilter.toLowerCase();
      results = results.where((Track t) => t.album.toLowerCase() == target);
    }

    if (folderFilter != null && folderFilter.isNotEmpty) {
      results = results.where((Track t) {
        if (t.localFilePath == null) return false;
        return p.dirname(t.localFilePath!).toLowerCase() == folderFilter.toLowerCase();
      });
    }

    final List<Track> sorted = results.toList();
    sorted.sort((Track a, Track b) {
      int cmp;
      switch (sortBy) {
        case LocalLibrarySortField.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case LocalLibrarySortField.artist:
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          if (cmp == 0) cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case LocalLibrarySortField.album:
          cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());
          if (cmp == 0) cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case LocalLibrarySortField.dateAdded:
          final DateTime dateA =
              _localTrackAddedAt[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime dateB =
              _localTrackAddedAt[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dateA.compareTo(dateB);
          break;
        case LocalLibrarySortField.duration:
          cmp = a.durationSeconds.compareTo(b.durationSeconds);
          break;
      }
      return ascending ? cmp : -cmp;
    });

    return sorted;
  }

  /// Groups tracks alphabetically (`A`–`Z` and `#`) for fast-scroll A-Z index bar.
  Map<String, List<Track>> groupTracksAlphabetically(List<Track> tracks) {
    final Map<String, List<Track>> grouped = <String, List<Track>>{};
    for (final Track track in tracks) {
      final String trimmed = track.title.trim();
      String bucket = '#';
      if (trimmed.isNotEmpty) {
        final String firstChar = trimmed[0].toUpperCase();
        if (RegExp(r'^[A-Z]$').hasMatch(firstChar)) {
          bucket = firstChar;
        }
      }
      grouped.putIfAbsent(bucket, () => <Track>[]).add(track);
    }
    return grouped;
  }

  /// Groups local tracks by folder path for Folder View browsing.
  Map<String, List<Track>> groupLocalTracksByFolder() {
    final Map<String, List<Track>> folders = <String, List<Track>>{};
    for (final Track track in _localTracksById.values) {
      final String folder = track.localFilePath != null && track.localFilePath!.isNotEmpty
          ? p.dirname(track.localFilePath!)
          : 'Internal Storage/Music';
      folders.putIfAbsent(folder, () => <Track>[]).add(track);
    }
    return folders;
  }

  // ===========================================================================
  // FAVORITES
  // ===========================================================================

  List<Track> getFavoriteTracks() {
    return _favoritesById.values.toList();
  }

  bool isTrackFavorite(String trackId) {
    return _favoritesById.containsKey(trackId);
  }

  Future<bool> toggleFavorite(Track track) async {
    final bool currentlyFav = _favoritesById.containsKey(track.id);
    final bool nextFav = !currentlyFav;

    if (nextFav) {
      _favoritesById[track.id] = track.copyWith(isFavorite: true);
    } else {
      _favoritesById.remove(track.id);
    }

    if (_localTracksById.containsKey(track.id)) {
      _localTracksById[track.id] = _localTracksById[track.id]!.copyWith(isFavorite: nextFav);
    }

    // Update inside playlists as well
    for (final String plId in _playlistsById.keys.toList()) {
      final Playlist pl = _playlistsById[plId]!;
      final List<Track> updatedTracks = pl.tracks
          .map((Track t) => t.id == track.id ? t.copyWith(isFavorite: nextFav) : t)
          .toList();
      _playlistsById[plId] = pl.copyWith(tracks: updatedTracks);
    }

    _schedulePersist();
    return nextFav;
  }

  // ===========================================================================
  // PLAYLISTS
  // ===========================================================================

  List<Playlist> getPlaylists() {
    final List<Playlist> list = _playlistsById.values.toList();
    list.sort((Playlist a, Playlist b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Playlist? getPlaylistById(String id) => _playlistsById[id];

  Future<void> savePlaylist(Playlist playlist) async {
    _playlistsById[playlist.id] = playlist;
    _schedulePersist();
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlistsById.remove(playlistId);
    _schedulePersist();
  }

  // ===========================================================================
  // PLAY HISTORY & RECENTLY PLAYED
  // ===========================================================================

  Future<void> recordPlayHistory(Track track, {required int playedSeconds}) async {
    _playHistory.removeWhere((PlayHistoryEntry e) => e.track.id == track.id);
    _playHistory.insert(
      0,
      PlayHistoryEntry(
        track: track,
        playedAt: DateTime.now(),
        playedSeconds: playedSeconds,
      ),
    );
    if (_playHistory.length > 500) {
      _playHistory.removeRange(500, _playHistory.length);
    }
    _schedulePersist();
  }

  List<Track> getRecentlyPlayedTracks({int limit = 25}) {
    return _playHistory.take(limit).map((PlayHistoryEntry e) => e.track).toList();
  }

  List<PlayHistoryEntry> getPlayHistory({int limit = 100}) {
    return _playHistory.take(limit).toList();
  }

  // ===========================================================================
  // DOWNLOAD TASKS
  // ===========================================================================

  List<DownloadTaskItem> getDownloadTasks() {
    return _downloadsByTrackId.values.toList();
  }

  DownloadTaskItem? getDownloadTask(String trackId) => _downloadsByTrackId[trackId];

  Future<void> saveDownloadTask(DownloadTaskItem item) async {
    _downloadsByTrackId[item.track.id] = item;
    if (item.isCompleted && item.localPath != null) {
      final Track updatedTrack = item.track.copyWith(
        isDownloaded: true,
        localFilePath: item.localPath,
      );
      if (_favoritesById.containsKey(updatedTrack.id)) {
        _favoritesById[updatedTrack.id] = updatedTrack.copyWith(isFavorite: true);
      }
    }
    _schedulePersist();
  }

  Future<void> removeDownloadTask(String trackId) async {
    _downloadsByTrackId.remove(trackId);
    _schedulePersist();
  }

  // ===========================================================================
  // USER SETTINGS & SAVED PLAYBACK QUEUE
  // ===========================================================================

  UserSettingsEntity getUserSettings() => _userSettings;

  Future<void> saveUserSettings(UserSettingsEntity settings) async {
    _userSettings = settings;
    _schedulePersist();
  }

  SavedPlaybackQueueState getSavedPlaybackQueue() => _savedPlaybackQueue;

  Future<void> savePlaybackQueue(SavedPlaybackQueueState queueState) async {
    _savedPlaybackQueue = queueState;
    _schedulePersist();
  }

  Future<void> setLastSyncTimestamp(DateTime timestamp) async {
    _lastSyncTimestamp = timestamp;
    _schedulePersist();
  }
}
