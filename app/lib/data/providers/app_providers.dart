import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/error/app_failure.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/anni_theme.dart';
import '../../domain/entities/download_task_item.dart';
import '../../domain/entities/lrc_line.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/music_repository.dart';
import '../local/local_database.dart';
import '../repositories/anni_music_repository_impl.dart';
import '../services/audio_player_service.dart';
import '../services/download_manager_service.dart';
import '../services/local_library_scanner.dart';

export '../../domain/entities/download_task_item.dart';
export '../../domain/entities/lrc_line.dart';
export '../../domain/entities/playlist.dart';
export '../../domain/entities/track.dart';
export '../../domain/entities/user_profile.dart';
export '../../domain/repositories/music_repository.dart';
export '../repositories/anni_music_repository_impl.dart' show kSeededLegalCatalog;
export '../services/audio_player_service.dart'
    show
        AnniAudioPlayerHandler,
        AnniRepeatMode,
        kEqualizerBandLabels,
        kEqualizerFrequenciesHz,
        kEqualizerPresets;

// =============================================================================
// 0. CORE INFRASTRUCTURE PROVIDERS
// =============================================================================

final Provider<LocalDatabase> localDatabaseProvider = Provider<LocalDatabase>((Ref ref) {
  final LocalDatabase db = LocalDatabase();
  unawaited(db.initialize());
  return db;
});

final Provider<DioClient> dioClientProvider = Provider<DioClient>((Ref ref) {
  return DioClient();
});

final Provider<LocalLibraryScanner> localLibraryScannerProvider =
    Provider<LocalLibraryScanner>((Ref ref) {
  final LocalDatabase db = ref.watch(localDatabaseProvider);
  return LocalLibraryScanner(localDatabase: db);
});

final Provider<DownloadManagerService> downloadManagerProvider =
    Provider<DownloadManagerService>((Ref ref) {
  final LocalDatabase db = ref.watch(localDatabaseProvider);
  final DioClient dio = ref.watch(dioClientProvider);
  return DownloadManagerService(localDatabase: db, dioClient: dio);
});

final Provider<MusicRepository> musicRepositoryProvider =
    Provider<MusicRepository>((Ref ref) {
  return AnniMusicRepositoryImpl(
    dioClient: ref.watch(dioClientProvider),
    localDatabase: ref.watch(localDatabaseProvider),
    libraryScanner: ref.watch(localLibraryScannerProvider),
    downloadManager: ref.watch(downloadManagerProvider),
  );
});

/// Global [AnniAudioPlayerHandler] instance (`audioHandlerProvider`).
/// Can be overridden in `main.dart` after `AudioService.init(...)`, or lazily instantiated here.
final Provider<AnniAudioPlayerHandler> audioHandlerProvider =
    Provider<AnniAudioPlayerHandler>((Ref ref) {
  final LocalDatabase db = ref.watch(localDatabaseProvider);
  return AnniAudioPlayerHandler(localDatabase: db);
});

// =============================================================================
// 1. AUTH STATE PROVIDER (`authStateProvider`)
// =============================================================================

class AuthState extends Equatable {
  const AuthState({
    required this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserProfile user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => !user.isGuest;

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[user, isLoading, errorMessage];
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier(this._repository)
      : super(AuthState(user: UserProfile.guest())) {
    unawaited(loadSession());
  }

  final MusicRepository _repository;

  Future<void> loadSession() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final UserProfile profile = await _repository.getCurrentUser();
      state = AuthState(user: profile, isLoading: false);
    } catch (e) {
      state = AuthState(user: UserProfile.guest(), isLoading: false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final UserProfile user = await _repository.login(email: email, password: password);
      state = AuthState(user: user, isLoading: false);
      unawaited(_repository.syncWithCloud());
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final UserProfile user = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthState(user: user, isLoading: false);
      return true;
    } on AppFailure catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState(user: UserProfile.guest(), isLoading: false);
  }
}

final StateNotifierProvider<AuthStateNotifier, AuthState> authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((Ref ref) {
  return AuthStateNotifier(ref.watch(musicRepositoryProvider));
});

// =============================================================================
// 2. USER SETTINGS PROVIDER (`userSettingsProvider`)
// =============================================================================

class UserSettingsNotifier extends StateNotifier<UserSettingsEntity> {
  UserSettingsNotifier(this._repository, this._audioHandler)
      : super(const UserSettingsEntity()) {
    unawaited(_hydrate());
  }

  final MusicRepository _repository;
  final AnniAudioPlayerHandler _audioHandler;

  Future<void> _hydrate() async {
    final UserSettingsEntity loaded = await _repository.getUserSettings();
    state = loaded;
  }

  Future<void> setThemeMode(String mode) async {
    state = await _repository.updateUserSettings(state.copyWith(themeMode: mode));
  }

  Future<void> toggleAmoledMode(bool enabled) async {
    await setThemeMode(enabled ? 'amoled' : 'dark');
  }

  Future<void> setStreamingQuality(String quality) async {
    state = await _repository.updateUserSettings(
      state.copyWith(streamingQuality: quality),
    );
  }

  Future<void> setDownloadQuality(String quality) async {
    state = await _repository.updateUserSettings(
      state.copyWith(downloadQuality: quality),
    );
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    final int clamped = seconds.clamp(0, 12);
    _audioHandler.setCrossfadeSeconds(clamped);
    state = await _repository.updateUserSettings(
      state.copyWith(crossfadeSeconds: clamped),
    );
  }

  Future<void> setGaplessPlayback(bool enabled) async {
    state = await _repository.updateUserSettings(
      state.copyWith(gaplessPlayback: enabled),
    );
  }

  Future<void> setReplayGain(bool enabled) async {
    _audioHandler.setReplayGainEnabled(enabled);
    state = await _repository.updateUserSettings(
      state.copyWith(replayGain: enabled),
    );
  }

  Future<void> setWifiOnlyDownloads(bool enabled) async {
    state = await _repository.updateUserSettings(
      state.copyWith(wifiOnlyDownloads: enabled),
    );
  }

  Future<void> setOfflineMode(bool enabled) async {
    state = await _repository.updateUserSettings(
      state.copyWith(offlineMode: enabled),
    );
  }

  Future<void> setAnalyticsOptIn(bool enabled) async {
    state = await _repository.updateUserSettings(
      state.copyWith(analyticsOptIn: enabled),
    );
  }
}

final StateNotifierProvider<UserSettingsNotifier, UserSettingsEntity> userSettingsProvider =
    StateNotifierProvider<UserSettingsNotifier, UserSettingsEntity>((Ref ref) {
  return UserSettingsNotifier(
    ref.watch(musicRepositoryProvider),
    ref.watch(audioHandlerProvider),
  );
});

// =============================================================================
// 3. PLAYBACK STATE PROVIDER (`playbackStateProvider`)
// =============================================================================

class AnniPlaybackState extends Equatable {
  const AnniPlaybackState({
    this.currentTrack,
    this.queue = const <Track>[],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = AnniRepeatMode.off,
    this.playbackSpeed = 1.0,
    this.sleepTimerRemaining,
  });

  final Track? currentTrack;
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final bool shuffleEnabled;
  final AnniRepeatMode repeatMode;
  final double playbackSpeed;
  final Duration? sleepTimerRemaining;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  AnniPlaybackState copyWith({
    Track? currentTrack,
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    bool? shuffleEnabled,
    AnniRepeatMode? repeatMode,
    double? playbackSpeed,
    Duration? sleepTimerRemaining,
    bool clearSleepTimer = false,
  }) {
    return AnniPlaybackState(
      currentTrack: currentTrack ?? this.currentTrack,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      sleepTimerRemaining:
          clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        currentTrack,
        queue,
        currentIndex,
        isPlaying,
        isBuffering,
        position,
        bufferedPosition,
        duration,
        shuffleEnabled,
        repeatMode,
        playbackSpeed,
        sleepTimerRemaining,
      ];
}

class PlaybackStateNotifier extends StateNotifier<AnniPlaybackState> {
  PlaybackStateNotifier(this._handler, this._repository)
      : super(
          AnniPlaybackState(
            currentTrack: kSeededLegalCatalog.first,
            queue: kSeededLegalCatalog,
            currentIndex: 0,
            duration: kSeededLegalCatalog.first.duration,
          ),
        ) {
    _bindStreams();
  }

  final AnniAudioPlayerHandler _handler;
  final MusicRepository _repository;
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  void _bindStreams() {
    if (_handler.currentQueue.isNotEmpty) {
      _syncFromHandler();
    }

    _subscriptions.add(
      _handler.engineChangedStream.listen((_) => _syncFromHandler()),
    );

    _subscriptions.add(
      _handler.positionStream.listen((Duration pos) {
        final Track? active = state.currentTrack;
        final Duration effectiveDuration = _handler.player.duration ??
            active?.duration ??
            state.duration;
        state = state.copyWith(
          position: pos,
          duration: effectiveDuration,
        );
      }),
    );

    _subscriptions.add(
      _handler.bufferedPositionStream.listen((Duration buffered) {
        state = state.copyWith(bufferedPosition: buffered);
      }),
    );

    _subscriptions.add(
      _handler.sleepTimerStream.listen((Duration? remaining) {
        state = state.copyWith(
          sleepTimerRemaining: remaining,
          clearSleepTimer: remaining == null,
        );
      }),
    );
  }

  void _syncFromHandler() {
    final Track? active = _handler.currentTrack ?? state.currentTrack;
    final List<Track> q =
        _handler.currentQueue.isNotEmpty ? _handler.currentQueue : state.queue;
    state = state.copyWith(
      currentTrack: active,
      queue: q,
      currentIndex: _handler.currentIndex,
      isPlaying: _handler.isPlaying,
      position: _handler.player.position,
      duration: _handler.player.duration ?? active?.duration ?? Duration.zero,
      shuffleEnabled: _handler.shuffleEnabled,
      repeatMode: _handler.repeatMode,
      playbackSpeed: _handler.playbackSpeed,
    );
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    await _handler.playTrack(track, contextQueue: queue ?? state.queue);
    unawaited(_repository.recordPlayEvent(track, playedSeconds: 0));
    _syncFromHandler();
  }

  Future<void> togglePlayPause() async {
    if (_handler.currentQueue.isEmpty && state.currentTrack != null) {
      await _handler.playTrack(state.currentTrack!, contextQueue: state.queue);
      return;
    }
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
    _syncFromHandler();
  }

  Future<void> seek(Duration position) async {
    await _handler.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> seekToRatio(double ratio) async {
    final int targetMs = (state.duration.inMilliseconds * ratio.clamp(0.0, 1.0)).round();
    await seek(Duration(milliseconds: targetMs));
  }

  Future<void> skipToNext() async {
    await _handler.skipToNext();
    _syncFromHandler();
  }

  Future<void> skipToPrevious() async {
    await _handler.skipToPrevious();
    _syncFromHandler();
  }

  Future<void> skipToQueueItem(int index) async {
    await _handler.skipToQueueItem(index);
    _syncFromHandler();
  }

  Future<void> playNext(Track track) async {
    await _handler.playNext(track);
    _syncFromHandler();
  }

  Future<void> addToQueue(Track track) async {
    await _handler.addToQueue(track);
    _syncFromHandler();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _handler.reorderQueue(oldIndex, newIndex);
    _syncFromHandler();
  }

  Future<void> removeFromQueue(int index) async {
    await _handler.removeFromQueue(index);
    _syncFromHandler();
  }

  Future<void> clearQueue() async {
    await _handler.clearQueue();
    _syncFromHandler();
  }

  Future<void> toggleShuffle() async {
    await _handler.toggleShuffle();
    _syncFromHandler();
  }

  Future<void> cycleRepeatMode() async {
    await _handler.cycleRepeatMode();
    _syncFromHandler();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _handler.setPlaybackSpeed(speed);
    _syncFromHandler();
  }

  void startSleepTimer(Duration duration, {bool endOfTrack = false}) {
    _handler.startSleepTimer(duration, endOfTrack: endOfTrack);
  }

  void cancelSleepTimer() {
    _handler.cancelSleepTimer();
  }

  void updateCurrentTrackMetadata(Track updated) {
    if (state.currentTrack?.id == updated.id) {
      state = state.copyWith(currentTrack: updated);
    }
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

final StateNotifierProvider<PlaybackStateNotifier, AnniPlaybackState> playbackStateProvider =
    StateNotifierProvider<PlaybackStateNotifier, AnniPlaybackState>((Ref ref) {
  return PlaybackStateNotifier(
    ref.watch(audioHandlerProvider),
    ref.watch(musicRepositoryProvider),
  );
});

// =============================================================================
// 4. LOCAL LIBRARY PROVIDER (`localLibraryProvider`)
// =============================================================================

class LocalLibraryState extends Equatable {
  const LocalLibraryState({
    this.tracks = const <Track>[],
    this.sortBy = LocalLibrarySortField.title,
    this.ascending = true,
    this.searchQuery = '',
    this.isScanning = false,
    this.errorMessage,
  });

  final List<Track> tracks;
  final LocalLibrarySortField sortBy;
  final bool ascending;
  final String searchQuery;
  final bool isScanning;
  final String? errorMessage;

  Map<String, List<Track>> get artistsMap {
    final Map<String, List<Track>> map = <String, List<Track>>{};
    for (final Track t in tracks) {
      map.putIfAbsent(t.artist, () => <Track>[]).add(t);
    }
    return map;
  }

  Map<String, List<Track>> get albumsMap {
    final Map<String, List<Track>> map = <String, List<Track>>{};
    for (final Track t in tracks) {
      map.putIfAbsent(t.album, () => <Track>[]).add(t);
    }
    return map;
  }

  Map<String, List<Track>> get foldersMap {
    final Map<String, List<Track>> map = <String, List<Track>>{};
    for (final Track t in tracks) {
      final String dir = t.localFilePath != null && t.localFilePath!.isNotEmpty
          ? File(t.localFilePath!).parent.path
          : 'Internal Storage/Music';
      map.putIfAbsent(dir, () => <Track>[]).add(t);
    }
    return map;
  }

  LocalLibraryState copyWith({
    List<Track>? tracks,
    LocalLibrarySortField? sortBy,
    bool? ascending,
    String? searchQuery,
    bool? isScanning,
    String? errorMessage,
  }) {
    return LocalLibraryState(
      tracks: tracks ?? this.tracks,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      searchQuery: searchQuery ?? this.searchQuery,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        tracks,
        sortBy,
        ascending,
        searchQuery,
        isScanning,
        errorMessage,
      ];
}

class LocalLibraryNotifier extends StateNotifier<LocalLibraryState> {
  LocalLibraryNotifier(this._repository) : super(const LocalLibraryState()) {
    unawaited(refreshLibrary());
  }

  final MusicRepository _repository;

  Future<void> refreshLibrary() async {
    final List<Track> tracks = await _repository.getLocalTracks(
      sortBy: state.sortBy,
      ascending: state.ascending,
      searchQuery: state.searchQuery,
    );
    state = state.copyWith(tracks: tracks, isScanning: false);
  }

  Future<void> scanDeviceStorage({bool forceRescan = true}) async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      await _repository.scanDeviceLibrary(forceRescan: forceRescan);
      await refreshLibrary();
    } catch (e) {
      state = state.copyWith(isScanning: false, errorMessage: e.toString());
    }
  }

  Future<void> importFiles() async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      await _repository.importAudioFiles();
      await refreshLibrary();
    } catch (e) {
      state = state.copyWith(isScanning: false, errorMessage: e.toString());
    }
  }

  Future<void> importFolder() async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      await _repository.importAudioFolder();
      await refreshLibrary();
    } catch (e) {
      state = state.copyWith(isScanning: false, errorMessage: e.toString());
    }
  }

  Future<void> setSortField(LocalLibrarySortField field, {bool? ascending}) async {
    final bool nextAsc =
        ascending ?? (state.sortBy == field ? !state.ascending : true);
    state = state.copyWith(sortBy: field, ascending: nextAsc);
    await refreshLibrary();
  }

  Future<void> setSearchQuery(String query) async {
    state = state.copyWith(searchQuery: query);
    await refreshLibrary();
  }

  Future<Track> updateTrackTags({
    required Track track,
    required String title,
    required String artist,
    required String album,
    required String genre,
    int? releaseYear,
  }) async {
    final Track updated = await _repository.updateTrackTags(
      track: track,
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      releaseYear: releaseYear,
    );
    await refreshLibrary();
    return updated;
  }

  Future<bool> setTrackAsRingtone(Track track) async {
    return _repository.setTrackAsRingtone(track);
  }
}

final StateNotifierProvider<LocalLibraryNotifier, LocalLibraryState> localLibraryProvider =
    StateNotifierProvider<LocalLibraryNotifier, LocalLibraryState>((Ref ref) {
  return LocalLibraryNotifier(ref.watch(musicRepositoryProvider));
});

// =============================================================================
// 5. SEARCH STATE PROVIDER (`searchStateProvider`)
// =============================================================================

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.sourceFilter,
    this.selectedGenre = 'All',
    this.results = const <Track>[],
    this.recentSearches = const <String>['Synthwave', 'Aiko Sora', 'Lo-Fi', 'Debussy'],
    this.isLoading = false,
    this.errorMessage,
  });

  final String query;
  final TrackSource? sourceFilter;
  final String selectedGenre;
  final List<Track> results;
  final List<String> recentSearches;
  final bool isLoading;
  final String? errorMessage;

  SearchState copyWith({
    String? query,
    TrackSource? sourceFilter,
    bool clearSourceFilter = false,
    String? selectedGenre,
    List<Track>? results,
    List<String>? recentSearches,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      sourceFilter: clearSourceFilter ? null : (sourceFilter ?? this.sourceFilter),
      selectedGenre: selectedGenre ?? this.selectedGenre,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        query,
        sourceFilter,
        selectedGenre,
        results,
        recentSearches,
        isLoading,
        errorMessage,
      ];
}

class SearchStateNotifier extends StateNotifier<SearchState> {
  SearchStateNotifier(this._repository)
      : super(SearchState(results: kSeededLegalCatalog)) {
    unawaited(executeSearch(''));
  }

  final MusicRepository _repository;
  Timer? _debounce;

  void onQueryChanged(String query) {
    state = state.copyWith(query: query, isLoading: true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(executeSearch(query));
    });
  }

  Future<void> setSourceFilter(TrackSource? source) async {
    state = state.copyWith(
      sourceFilter: source,
      clearSourceFilter: source == null,
      isLoading: true,
    );
    await executeSearch(state.query);
  }

  Future<void> setGenreFilter(String genre) async {
    state = state.copyWith(selectedGenre: genre, isLoading: true);
    await executeSearch(state.query);
  }

  Future<void> executeSearch(String query) async {
    try {
      final List<Track> found = await _repository.searchTracks(
        query: query,
        sourceFilter: state.sourceFilter,
        genre: state.selectedGenre == 'All' ? null : state.selectedGenre,
      );

      final List<String> updatedHistory = List<String>.from(state.recentSearches);
      if (query.trim().length >= 2 && !updatedHistory.contains(query.trim())) {
        updatedHistory.insert(0, query.trim());
        if (updatedHistory.length > 10) {
          updatedHistory.removeLast();
        }
      }

      state = state.copyWith(
        results: found,
        recentSearches: updatedHistory,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: const <String>[]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<SearchStateNotifier, SearchState> searchStateProvider =
    StateNotifierProvider<SearchStateNotifier, SearchState>((Ref ref) {
  return SearchStateNotifier(ref.watch(musicRepositoryProvider));
});

// =============================================================================
// 6. RECOMMENDATIONS & TRENDING PROVIDERS (`recommendationsProvider`)
// =============================================================================

final FutureProvider<List<Track>> recommendationsProvider =
    FutureProvider<List<Track>>((Ref ref) async {
  final MusicRepository repo = ref.watch(musicRepositoryProvider);
  return repo.getRecommendations(limit: 20);
});

final FutureProviderFamily<List<Track>, String?> trendingTracksProvider =
    FutureProvider.family<List<Track>, String?>((Ref ref, String? genre) async {
  final MusicRepository repo = ref.watch(musicRepositoryProvider);
  return repo.getTrendingTracks(genre: genre, limit: 20);
});

final Provider<List<Track>> recentlyPlayedProvider = Provider<List<Track>>((Ref ref) {
  final LocalDatabase db = ref.watch(localDatabaseProvider);
  final List<Track> recent = db.getRecentlyPlayedTracks(limit: 15);
  return recent.isNotEmpty ? recent : kSeededLegalCatalog.take(4).toList();
});

// =============================================================================
// 7. PLAYLISTS PROVIDER (`playlistsProvider`)
// =============================================================================

class PlaylistsNotifier extends StateNotifier<List<Playlist>> {
  PlaylistsNotifier(this._repository) : super(const <Playlist>[]) {
    unawaited(loadPlaylists());
  }

  final MusicRepository _repository;

  Future<void> loadPlaylists() async {
    state = await _repository.getPlaylists();
  }

  Future<Playlist> createPlaylist({
    required String name,
    String description = '',
    bool isPublic = false,
    List<Track> initialTracks = const <Track>[],
  }) async {
    final Playlist created = await _repository.createPlaylist(
      name: name,
      description: description,
      isPublic: isPublic,
      initialTracks: initialTracks,
    );
    await loadPlaylists();
    return created;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _repository.deletePlaylist(playlistId);
    await loadPlaylists();
  }

  Future<void> addTrackToPlaylist(String playlistId, Track track) async {
    await _repository.addTrackToPlaylist(playlistId, track);
    await loadPlaylists();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _repository.removeTrackFromPlaylist(playlistId, trackId);
    await loadPlaylists();
  }

  Future<String> exportToM3u(Playlist playlist) async {
    return _repository.exportPlaylistToM3u(playlist);
  }

  Future<Playlist> importFromM3u(String m3uContent, {String? name}) async {
    final Playlist imported =
        await _repository.importPlaylistFromM3u(m3uContent, name: name);
    await loadPlaylists();
    return imported;
  }
}

final StateNotifierProvider<PlaylistsNotifier, List<Playlist>> playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, List<Playlist>>((Ref ref) {
  return PlaylistsNotifier(ref.watch(musicRepositoryProvider));
});

// =============================================================================
// 8. FAVORITES PROVIDER (`favoritesProvider`)
// =============================================================================

class FavoritesNotifier extends StateNotifier<List<Track>> {
  FavoritesNotifier(this._repository, this._ref) : super(const <Track>[]) {
    unawaited(loadFavorites());
  }

  final MusicRepository _repository;
  final Ref _ref;

  Future<void> loadFavorites() async {
    state = await _repository.getFavoriteTracks();
  }

  bool isFavorite(String trackId) {
    return state.any((Track t) => t.id == trackId);
  }

  Future<bool> toggleFavorite(Track track) async {
    final bool isNowFav = await _repository.toggleFavorite(track);
    await loadFavorites();
    _ref
        .read(playbackStateProvider.notifier)
        .updateCurrentTrackMetadata(track.copyWith(isFavorite: isNowFav));
    return isNowFav;
  }
}

final StateNotifierProvider<FavoritesNotifier, List<Track>> favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, List<Track>>((Ref ref) {
  return FavoritesNotifier(ref.watch(musicRepositoryProvider), ref);
});

// =============================================================================
// 9. DOWNLOADS PROVIDER (`downloadsProvider`)
// =============================================================================

class DownloadsState extends Equatable {
  const DownloadsState({
    this.tasks = const <DownloadTaskItem>[],
    this.storageUsedBytes = 0,
  });

  final List<DownloadTaskItem> tasks;
  final int storageUsedBytes;

  List<DownloadTaskItem> get completedTasks =>
      tasks.where((DownloadTaskItem t) => t.isCompleted).toList();

  List<DownloadTaskItem> get activeTasks =>
      tasks.where((DownloadTaskItem t) => !t.isCompleted).toList();

  String get formattedStorageUsed {
    final double mb = storageUsedBytes / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  DownloadsState copyWith({
    List<DownloadTaskItem>? tasks,
    int? storageUsedBytes,
  }) {
    return DownloadsState(
      tasks: tasks ?? this.tasks,
      storageUsedBytes: storageUsedBytes ?? this.storageUsedBytes,
    );
  }

  @override
  List<Object?> get props => <Object?>[tasks, storageUsedBytes];
}

class DownloadsNotifier extends StateNotifier<DownloadsState> {
  DownloadsNotifier(this._repository) : super(const DownloadsState()) {
    unawaited(_init());
  }

  final MusicRepository _repository;
  StreamSubscription<List<DownloadTaskItem>>? _subscription;

  Future<void> _init() async {
    final List<DownloadTaskItem> initial = await _repository.getDownloads();
    final int usedBytes = await _repository.getDownloadedStorageBytes();
    state = DownloadsState(tasks: initial, storageUsedBytes: usedBytes);

    _subscription = _repository.watchDownloads().listen((List<DownloadTaskItem> tasks) async {
      final int bytes = await _repository.getDownloadedStorageBytes();
      state = state.copyWith(tasks: tasks, storageUsedBytes: bytes);
    });
  }

  Future<void> enqueueDownload(Track track) async {
    await _repository.enqueueDownload(track);
  }

  Future<void> pauseDownload(String trackId) async {
    await _repository.pauseDownload(trackId);
  }

  Future<void> resumeDownload(String trackId) async {
    await _repository.resumeDownload(trackId);
  }

  Future<void> retryDownload(String trackId) async {
    await _repository.retryDownload(trackId);
  }

  Future<void> deleteDownload(String trackId) async {
    await _repository.deleteDownload(trackId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<DownloadsNotifier, DownloadsState> downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, DownloadsState>((Ref ref) {
  return DownloadsNotifier(ref.watch(musicRepositoryProvider));
});

// =============================================================================
// 10. EQUALIZER PROVIDER (`equalizerProvider`)
// =============================================================================

class EqualizerState extends Equatable {
  const EqualizerState({
    this.enabled = true,
    this.currentPreset = 'Signature Cinema',
    this.bands = const <double>[2.5, 3.2, 2.0, 0.5, -0.4, 0.4, 1.6, 2.4, 3.0, 2.6],
    this.bassBoostStrength = 250,
    this.virtualizerStrength = 200,
    this.replayGainEnabled = true,
  });

  final bool enabled;
  final String currentPreset;
  final List<double> bands;
  final int bassBoostStrength;
  final int virtualizerStrength;
  final bool replayGainEnabled;

  List<String> get availablePresets => kEqualizerPresets.keys.toList();

  EqualizerState copyWith({
    bool? enabled,
    String? currentPreset,
    List<double>? bands,
    int? bassBoostStrength,
    int? virtualizerStrength,
    bool? replayGainEnabled,
  }) {
    return EqualizerState(
      enabled: enabled ?? this.enabled,
      currentPreset: currentPreset ?? this.currentPreset,
      bands: bands ?? this.bands,
      bassBoostStrength: bassBoostStrength ?? this.bassBoostStrength,
      virtualizerStrength: virtualizerStrength ?? this.virtualizerStrength,
      replayGainEnabled: replayGainEnabled ?? this.replayGainEnabled,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        enabled,
        currentPreset,
        bands,
        bassBoostStrength,
        virtualizerStrength,
        replayGainEnabled,
      ];
}

class EqualizerNotifier extends StateNotifier<EqualizerState> {
  EqualizerNotifier(this._handler, this._repository)
      : super(
          EqualizerState(
            enabled: _handler.equalizerEnabled,
            currentPreset: _handler.equalizerPreset,
            bands: _handler.equalizerBands,
            bassBoostStrength: _handler.bassBoostStrength,
            virtualizerStrength: _handler.virtualizerStrength,
            replayGainEnabled: _handler.replayGainEnabled,
          ),
        );

  final AnniAudioPlayerHandler _handler;
  final MusicRepository _repository;

  Future<void> setEnabled(bool enabled) async {
    await _handler.setEqualizerEnabled(enabled);
    state = state.copyWith(enabled: enabled);
    await _persistToSettings();
  }

  Future<void> selectPreset(String presetName) async {
    await _handler.selectEqualizerPreset(presetName);
    state = state.copyWith(
      currentPreset: _handler.equalizerPreset,
      bands: _handler.equalizerBands,
    );
    await _persistToSettings();
  }

  Future<void> setBandGain(int bandIndex, double gainDb) async {
    await _handler.setEqualizerBand(bandIndex, gainDb);
    state = state.copyWith(
      currentPreset: 'Custom',
      bands: _handler.equalizerBands,
    );
    await _persistToSettings();
  }

  Future<void> setBassBoost(int strength) async {
    await _handler.setBassBoostStrength(strength);
    state = state.copyWith(bassBoostStrength: _handler.bassBoostStrength);
    await _persistToSettings();
  }

  Future<void> setVirtualizer(int strength) async {
    await _handler.setVirtualizerStrength(strength);
    state = state.copyWith(virtualizerStrength: _handler.virtualizerStrength);
    await _persistToSettings();
  }

  Future<void> setReplayGain(bool enabled) async {
    _handler.setReplayGainEnabled(enabled);
    state = state.copyWith(replayGainEnabled: enabled);
    await _persistToSettings();
  }

  Future<void> openSystemEqualizer() async {
    await _handler.openSystemEqualizerSession();
  }

  Future<void> _persistToSettings() async {
    final UserSettingsEntity current = await _repository.getUserSettings();
    await _repository.updateUserSettings(
      current.copyWith(
        equalizerEnabled: state.enabled,
        equalizerPreset: state.currentPreset,
        equalizerBands: state.bands,
        bassBoostStrength: state.bassBoostStrength,
        virtualizerStrength: state.virtualizerStrength,
        replayGain: state.replayGainEnabled,
      ),
    );
  }
}

final StateNotifierProvider<EqualizerNotifier, EqualizerState> equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((Ref ref) {
  return EqualizerNotifier(
    ref.watch(audioHandlerProvider),
    ref.watch(musicRepositoryProvider),
  );
});

// =============================================================================
// 11. LYRICS PROVIDER (`lyricsProvider`)
// =============================================================================

final FutureProvider<List<LrcLine>> lyricsProvider =
    FutureProvider<List<LrcLine>>((Ref ref) async {
  final Track? currentTrack =
      ref.watch(playbackStateProvider.select((AnniPlaybackState s) => s.currentTrack));
  if (currentTrack == null) {
    return const <LrcLine>[];
  }
  final MusicRepository repo = ref.watch(musicRepositoryProvider);
  return repo.getLyricsForTrack(currentTrack);
});

// =============================================================================
// 12. DYNAMIC PALETTE PROVIDER (`dynamicPaletteProvider`)
// =============================================================================

final FutureProvider<Color> dynamicPaletteProvider = FutureProvider<Color>((Ref ref) async {
  final Track? currentTrack =
      ref.watch(playbackStateProvider.select((AnniPlaybackState s) => s.currentTrack));
  if (currentTrack == null) {
    return AnniTheme.accentViolet;
  }

  final Color fallbackColor = AnniTheme.parseHexColor(
    currentTrack.dominantColor,
    fallback: AnniTheme.accentViolet,
  );

  final String? art = currentTrack.artworkUrl;
  if (art == null || art.isEmpty) {
    return fallbackColor;
  }

  try {
    final ImageProvider imageProvider = art.startsWith('http')
        ? CachedNetworkImageProvider(art)
        : FileImage(File(art)) as ImageProvider;

    final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
      imageProvider,
      size: const Size(96, 96),
      maximumColorCount: 12,
    ).timeout(const Duration(seconds: 3));

    return palette.vibrantColor?.color ??
        palette.lightVibrantColor?.color ??
        palette.dominantColor?.color ??
        fallbackColor;
  } catch (_) {
    return fallbackColor;
  }
});
