import '../entities/download_task_item.dart';
import '../entities/lrc_line.dart';
import '../entities/playlist.dart';
import '../entities/track.dart';
import '../entities/user_profile.dart';

/// Sort options for local audio library browsing.
enum LocalLibrarySortField {
  title,
  artist,
  album,
  dateAdded,
  duration,
}

/// Abstract contract for authentication & user settings management.
abstract class AuthRepository {
  Future<UserProfile> getCurrentUser();
  Future<UserProfile> login({required String email, required String password});
  Future<UserProfile> loginWithGoogle({
    required String idToken,
    String? email,
    String? displayName,
    String? avatarUrl,
  });
  Future<UserProfile> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<bool> forgotPassword(String email);
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  });
  Future<UserProfile> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
  });
  Future<void> logout();
  Future<UserSettingsEntity> getUserSettings();
  Future<UserSettingsEntity> updateUserSettings(UserSettingsEntity settings);
}

/// Abstract contract for unified hybrid search, catalog discovery, recommendations, and lyrics.
abstract class CatalogRepository {
  Future<List<Track>> searchTracks({
    required String query,
    TrackSource? sourceFilter,
    String? genre,
    int page = 1,
    int limit = 25,
  });

  Future<List<Track>> getTrendingTracks({String? genre, int limit = 20});

  Future<List<Track>> getRecommendations({int limit = 20});

  Future<List<LrcLine>> getLyricsForTrack(Track track);

  Future<void> recordPlayEvent(Track track, {required int playedSeconds});
}

/// Abstract contract for local and cloud playlists + favorites management.
abstract class PlaylistRepository {
  Future<List<Playlist>> getPlaylists();
  Future<Playlist> createPlaylist({
    required String name,
    String description = '',
    bool isPublic = false,
    List<Track> initialTracks = const <Track>[],
  });
  Future<Playlist> updatePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String playlistId);
  Future<Playlist> addTrackToPlaylist(String playlistId, Track track);
  Future<Playlist> removeTrackFromPlaylist(String playlistId, String trackId);
  Future<String> exportPlaylistToM3u(Playlist playlist);
  Future<Playlist> importPlaylistFromM3u(String m3uContent, {String? name});

  Future<List<Track>> getFavoriteTracks();
  Future<bool> toggleFavorite(Track track);
}

/// Abstract contract for device storage scanning, ID3 tag editing, and ringtone setting.
abstract class LocalLibraryRepository {
  Future<List<Track>> getLocalTracks({
    LocalLibrarySortField sortBy = LocalLibrarySortField.title,
    bool ascending = true,
    String? searchQuery,
  });
  Future<List<Track>> scanDeviceLibrary({bool forceRescan = false});
  Future<List<Track>> importAudioFiles();
  Future<List<Track>> importAudioFolder();
  Future<Track> updateTrackTags({
    required Track track,
    required String title,
    required String artist,
    required String album,
    required String genre,
    int? releaseYear,
  });
  Future<bool> setTrackAsRingtone(Track track);
}

/// Abstract contract for legal offline track downloads.
abstract class DownloadRepository {
  Stream<List<DownloadTaskItem>> watchDownloads();
  Future<List<DownloadTaskItem>> getDownloads();
  Future<void> enqueueDownload(Track track);
  Future<void> pauseDownload(String trackId);
  Future<void> resumeDownload(String trackId);
  Future<void> retryDownload(String trackId);
  Future<void> deleteDownload(String trackId);
  Future<int> getDownloadedStorageBytes();
}

/// Abstract contract for bi-directional delta cloud synchronization.
abstract class SyncRepository {
  Future<void> syncWithCloud();
}

/// Unified repository interface combining Auth, Catalog, Playlists, LocalLibrary, Downloads, and Sync.
abstract class MusicRepository
    implements
        AuthRepository,
        CatalogRepository,
        PlaylistRepository,
        LocalLibraryRepository,
        DownloadRepository,
        SyncRepository {}
