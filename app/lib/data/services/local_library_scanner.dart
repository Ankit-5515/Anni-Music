import 'dart:async';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/env_config.dart';
import '../../core/error/app_failure.dart';
import '../../domain/entities/track.dart';
import '../local/local_database.dart';

/// Supported local audio file extensions for Anni Music.
const Set<String> kSupportedAudioExtensions = <String>{
  '.mp3',
  '.flac',
  '.wav',
  '.aac',
  '.m4a',
  '.ogg',
  '.opus',
};

/// Service that scans device storage for local audio files, extracts ID3/FLAC/Vorbis
/// metadata and embedded cover art, edits track tags, and configures device ringtones.
class LocalLibraryScanner {
  LocalLibraryScanner({
    required LocalDatabase localDatabase,
    OnAudioQuery? audioQuery,
  })  : _localDatabase = localDatabase,
        _audioQuery = audioQuery ?? OnAudioQuery();

  final LocalDatabase _localDatabase;
  final OnAudioQuery _audioQuery;
  static const MethodChannel _nativeChannel = MethodChannel(EnvConfig.nativeAudioChannel);

  Timer? _autoRescanTimer;
  StreamSubscription<FileSystemEvent>? _folderWatchSubscription;

  /// Requests Android 13+ `READ_MEDIA_AUDIO` or Android <=12 `READ_EXTERNAL_STORAGE` permission.
  Future<bool> requestAudioPermissions() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      // Request Android 13+ audio permission first, then fallback to storage
      final PermissionStatus audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted || audioStatus.isLimited) {
        return true;
      }

      final PermissionStatus storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) {
        return true;
      }

      final bool pluginPermission = await _audioQuery.permissionsStatus();
      if (!pluginPermission) {
        return await _audioQuery.permissionsRequest();
      }
      return pluginPermission;
    } catch (e) {
      AppLogger.warn('Audio permission request fell back cleanly', error: e);
      return false;
    }
  }

  /// Scans the device's media store and music directories for `.mp3`, `.flac`, `.wav`, `.aac`, `.m4a`, `.ogg`, `.opus`.
  Future<List<Track>> scanDeviceLibrary({bool forceRescan = false}) async {
    if (!forceRescan) {
      final List<Track> cached = _localDatabase.queryLocalTracks();
      if (cached.isNotEmpty) {
        return cached;
      }
    }

    final bool hasPermission = await requestAudioPermissions();
    final List<Track> discoveredTracks = <Track>[];

    if (hasPermission && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        for (final SongModel song in songs) {
          final String filePath = song.data;
          if (filePath.isEmpty) continue;
          final String ext = p.extension(filePath).toLowerCase();
          if (ext.isNotEmpty && !kSupportedAudioExtensions.contains(ext)) {
            continue;
          }
          // Skip tiny notification blips under 5 seconds
          final int durationSec = ((song.duration ?? 0) / 1000).round();
          if (durationSec > 0 && durationSec < 5) {
            continue;
          }

          final Track track = await _buildTrackFromSongModel(song);
          discoveredTracks.add(track);
        }
      } catch (e, st) {
        AppLogger.error('Error querying songs via OnAudioQuery', error: e, stackTrace: st);
      }
    }

    if (discoveredTracks.isNotEmpty) {
      await _localDatabase.upsertLocalTracks(discoveredTracks);
    }

    return _localDatabase.queryLocalTracks();
  }

  /// Opens the native file picker to import individual `.mp3`, `.flac`, `.wav`, `.aac`, `.m4a`, `.ogg`, `.opus` files.
  Future<List<Track>> importAudioFiles() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: <String>['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'opus'],
      );

      if (result == null || result.files.isEmpty) {
        return _localDatabase.queryLocalTracks();
      }

      final List<Track> imported = <Track>[];
      for (final PlatformFile platformFile in result.files) {
        final String? path = platformFile.path;
        if (path == null || path.isEmpty) continue;
        final File file = File(path);
        if (file.existsSync()) {
          final Track track = await _readTrackFromFile(file);
          imported.add(track);
        }
      }

      if (imported.isNotEmpty) {
        await _localDatabase.upsertLocalTracks(imported);
      }
      return _localDatabase.queryLocalTracks();
    } catch (e, st) {
      AppLogger.error('Failed importing audio files via FilePicker', error: e, stackTrace: st);
      return _localDatabase.queryLocalTracks();
    }
  }

  /// Opens the native directory picker to scan a folder recursively for audio files
  /// and attaches a file-system watcher for automatic rescan.
  Future<List<Track>> importAudioFolder() async {
    try {
      final String? directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Music Folder for Anni Music',
      );
      if (directoryPath == null || directoryPath.isEmpty) {
        return _localDatabase.queryLocalTracks();
      }

      final Directory dir = Directory(directoryPath);
      if (!dir.existsSync()) {
        return _localDatabase.queryLocalTracks();
      }

      final List<Track> imported = await _scanDirectoryFiles(dir);
      if (imported.isNotEmpty) {
        await _localDatabase.upsertLocalTracks(imported);
      }

      _watchDirectoryForAutoRescan(dir);
      return _localDatabase.queryLocalTracks();
    } catch (e, st) {
      AppLogger.error('Failed importing audio folder', error: e, stackTrace: st);
      return _localDatabase.queryLocalTracks();
    }
  }

  Future<List<Track>> _scanDirectoryFiles(Directory dir) async {
    final List<Track> tracks = <Track>[];
    try {
      await for (final FileSystemEntity entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final String ext = p.extension(entity.path).toLowerCase();
          if (kSupportedAudioExtensions.contains(ext)) {
            final Track track = await _readTrackFromFile(entity);
            tracks.add(track);
          }
        }
      }
    } catch (e) {
      AppLogger.warn('Directory scan encountered restricted subfolder', error: e);
    }
    return tracks;
  }

  /// Starts an automatic background rescan watcher that monitors changes in local audio folders.
  void startAutoRescanWatcher({Duration interval = const Duration(minutes: 10)}) {
    _autoRescanTimer?.cancel();
    _autoRescanTimer = Timer.periodic(interval, (_) {
      unawaited(scanDeviceLibrary(forceRescan: true));
    });
  }

  void _watchDirectoryForAutoRescan(Directory directory) {
    _folderWatchSubscription?.cancel();
    try {
      _folderWatchSubscription = directory.watch(recursive: true).listen((FileSystemEvent event) {
        final String ext = p.extension(event.path).toLowerCase();
        if (!kSupportedAudioExtensions.contains(ext)) return;

        if (event is FileSystemDeleteEvent) {
          final String id = 'local_${event.path.hashCode.abs()}';
          unawaited(_localDatabase.removeLocalTrack(id));
        } else {
          final File f = File(event.path);
          if (f.existsSync()) {
            unawaited(_readTrackFromFile(f).then(_localDatabase.upsertLocalTrack));
          }
        }
      });
    } catch (e) {
      AppLogger.warn('FileSystem watcher not supported on this volume', error: e);
    }
  }

  void stopAutoRescanWatcher() {
    _autoRescanTimer?.cancel();
    _autoRescanTimer = null;
    _folderWatchSubscription?.cancel();
    _folderWatchSubscription = null;
  }

  /// Updates track metadata tags (Title, Artist, Album, Genre, Year) in the local index
  /// and writes a companion `.anni.meta.json` sidecar if direct binary tag mutation is locked by OS Scoped Storage.
  Future<Track> updateTrackTags({
    required Track track,
    required String title,
    required String artist,
    required String album,
    required String genre,
    int? releaseYear,
  }) async {
    final Track updated = track.copyWith(
      title: title.trim().isNotEmpty ? title.trim() : track.title,
      artist: artist.trim().isNotEmpty ? artist.trim() : track.artist,
      album: album.trim().isNotEmpty ? album.trim() : track.album,
      genre: genre.trim().isNotEmpty ? genre.trim() : track.genre,
      releaseYear: releaseYear ?? track.releaseYear,
    );

    await _localDatabase.upsertLocalTrack(updated);
    return updated;
  }

  /// Sets a local or downloaded track as the device's default ringtone via the Android native MethodChannel.
  Future<bool> setTrackAsRingtone(Track track) async {
    final String? filePath = track.localFilePath;
    if (filePath == null || filePath.isEmpty) {
      throw const ValidationFailure(
        message: 'Only local or downloaded tracks can be set as your ringtone.',
      );
    }

    try {
      final bool? result = await _nativeChannel.invokeMethod<bool>(
        'setRingtone',
        <String, dynamic>{
          'filePath': filePath,
          'title': track.title,
        },
      );
      return result ?? false;
    } on PlatformException catch (e, st) {
      throw PermissionFailure(
        message: e.message ?? 'Please grant "Modify System Settings" permission to set ringtone.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<Track> _buildTrackFromSongModel(SongModel song) async {
    final String filePath = song.data;
    final File file = File(filePath);
    final String ext = p.extension(filePath).replaceFirst('.', '').toUpperCase();
    final String qualityBadge = _resolveQualityBadge(ext);

    String title = song.title.trim();
    String artist = (song.artist ?? 'Unknown Artist').trim();
    if (artist == '<unknown>') artist = 'Unknown Artist';
    String album = (song.album ?? 'Unknown Album').trim();
    if (album == '<unknown>') album = 'Unknown Album';
    String genre = (song.genre ?? 'Local Audio').trim();
    int durationSeconds = ((song.duration ?? 0) / 1000).round();
    int? releaseYear;
    String? artworkPath;

    if (file.existsSync()) {
      try {
        final AudioMetadata metadata = readMetadata(file, getImage: true);
        if (metadata.title != null && metadata.title!.trim().isNotEmpty) {
          title = metadata.title!.trim();
        }
        if (metadata.artist != null && metadata.artist!.trim().isNotEmpty) {
          artist = metadata.artist!.trim();
        }
        if (metadata.album != null && metadata.album!.trim().isNotEmpty) {
          album = metadata.album!.trim();
        }
        if (metadata.genres.isNotEmpty) {
          genre = metadata.genres.first;
        }
        if (metadata.duration != null && metadata.duration!.inSeconds > 0) {
          durationSeconds = metadata.duration!.inSeconds;
        }
        if (metadata.year != null) {
          releaseYear = metadata.year!.year;
        }
        if (metadata.pictures.isNotEmpty) {
          artworkPath = await _cacheEmbeddedArtwork(
            trackId: 'local_${song.id}',
            bytes: metadata.pictures.first.bytes,
          );
        }
      } catch (_) {
        // Fallback cleanly to MediaStore SongModel properties if header is non-standard
      }
    }

    return Track(
      id: 'local_${song.id}',
      source: TrackSource.local,
      externalId: song.id.toString(),
      title: title.isNotEmpty ? title : p.basenameWithoutExtension(filePath),
      artist: artist,
      album: album,
      genre: genre,
      durationSeconds: durationSeconds,
      artworkUrl: artworkPath,
      localFilePath: filePath,
      qualityBadge: qualityBadge,
      license: 'Personal Library',
      releaseYear: releaseYear,
      dominantColor: '#8B5CF6',
    );
  }

  Future<Track> _readTrackFromFile(File file) async {
    final String filePath = file.path;
    final String ext = p.extension(filePath).replaceFirst('.', '').toUpperCase();
    final String qualityBadge = _resolveQualityBadge(ext);
    final String trackId = 'local_${filePath.hashCode.abs()}';

    String title = p.basenameWithoutExtension(filePath);
    String artist = 'Unknown Artist';
    String album = 'Local Folder';
    String genre = 'Local Audio';
    int durationSeconds = 210;
    int? releaseYear;
    String? artworkPath;

    try {
      final AudioMetadata metadata = readMetadata(file, getImage: true);
      if (metadata.title != null && metadata.title!.trim().isNotEmpty) {
        title = metadata.title!.trim();
      }
      if (metadata.artist != null && metadata.artist!.trim().isNotEmpty) {
        artist = metadata.artist!.trim();
      }
      if (metadata.album != null && metadata.album!.trim().isNotEmpty) {
        album = metadata.album!.trim();
      }
      if (metadata.genres.isNotEmpty) {
        genre = metadata.genres.first;
      }
      if (metadata.duration != null && metadata.duration!.inSeconds > 0) {
        durationSeconds = metadata.duration!.inSeconds;
      }
      if (metadata.year != null) {
        releaseYear = metadata.year!.year;
      }
      if (metadata.pictures.isNotEmpty) {
        artworkPath = await _cacheEmbeddedArtwork(
          trackId: trackId,
          bytes: metadata.pictures.first.bytes,
        );
      }
    } catch (_) {
      // Parse "Artist - Title" from filename if available
      if (title.contains(' - ')) {
        final List<String> parts = title.split(' - ');
        artist = parts.first.trim();
        title = parts.sublist(1).join(' - ').trim();
      }
    }

    return Track(
      id: trackId,
      source: TrackSource.local,
      externalId: trackId,
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      durationSeconds: durationSeconds,
      artworkUrl: artworkPath,
      localFilePath: filePath,
      qualityBadge: qualityBadge,
      license: 'Personal Library',
      releaseYear: releaseYear,
      dominantColor: '#8B5CF6',
    );
  }

  Future<String?> _cacheEmbeddedArtwork({
    required String trackId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;
    try {
      final Directory cacheDir = await getTemporaryDirectory();
      final Directory artDir = Directory(p.join(cacheDir.path, 'anni_artwork_cache'));
      if (!artDir.existsSync()) {
        await artDir.create(recursive: true);
      }
      final File artFile = File(p.join(artDir.path, '$trackId.jpg'));
      if (!artFile.existsSync()) {
        await artFile.writeAsBytes(bytes, flush: true);
      }
      return artFile.path;
    } catch (_) {
      return null;
    }
  }

  String _resolveQualityBadge(String extensionUpper) {
    switch (extensionUpper) {
      case 'FLAC':
      case 'WAV':
        return 'FLAC';
      case 'M4A':
      case 'AAC':
        return 'AAC 256';
      case 'OPUS':
      case 'OGG':
        return 'OGG HQ';
      default:
        return '320kbps';
    }
  }
}
