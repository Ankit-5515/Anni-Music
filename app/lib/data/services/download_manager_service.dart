import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/error/app_failure.dart';
import '../../core/network/dio_client.dart';
import '../../domain/entities/download_task_item.dart';
import '../../domain/entities/track.dart';
import '../local/local_database.dart';

/// Chunked HTTP Range downloader for legal Creative Commons / Public Domain streaming tracks
/// (Jamendo & Internet Archive). Supports queueing, pause/resume via `Range: bytes=N-`,
/// retry, deletion, and storage calculation.
class DownloadManagerService {
  DownloadManagerService({
    required LocalDatabase localDatabase,
    required DioClient dioClient,
  })  : _localDatabase = localDatabase,
        _dioClient = dioClient {
    _hydrateFromDatabase();
  }

  final LocalDatabase _localDatabase;
  final DioClient _dioClient;

  final Map<String, DownloadTaskItem> _tasks = <String, DownloadTaskItem>{};
  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};
  final StreamController<List<DownloadTaskItem>> _tasksStreamController =
      StreamController<List<DownloadTaskItem>>.broadcast();

  bool _isProcessingQueue = false;

  void _hydrateFromDatabase() {
    for (final DownloadTaskItem saved in _localDatabase.getDownloadTasks()) {
      // Any task that was mid-download when app closed transitions to paused so user can resume
      final DownloadTaskItem normalized = saved.status == DownloadStatus.downloading
          ? saved.copyWith(status: DownloadStatus.paused)
          : saved;
      _tasks[normalized.track.id] = normalized;
    }
    _emitTasks();
  }

  Stream<List<DownloadTaskItem>> watchDownloads() => _tasksStreamController.stream;

  List<DownloadTaskItem> getDownloads() => _tasks.values.toList();

  /// Enqueues a legal streaming track for offline download.
  Future<void> enqueueDownload(Track track) async {
    if (track.source == TrackSource.youtube) {
      throw const ValidationFailure(
        message: 'YouTube tracks cannot be downloaded offline per YouTube Terms of Service.',
      );
    }

    final DownloadTaskItem? existing = _tasks[track.id];
    if (existing != null && existing.isCompleted) {
      return;
    }

    final String targetPath = await _resolveTargetFilePath(track);
    final DownloadTaskItem item = DownloadTaskItem(
      track: track,
      progress: existing?.progress ?? 0.0,
      status: DownloadStatus.queued,
      bytesDownloaded: existing?.bytesDownloaded ?? 0,
      totalBytes: existing?.totalBytes ?? 0,
      localPath: targetPath,
    );

    _tasks[track.id] = item;
    await _localDatabase.saveDownloadTask(item);
    _emitTasks();
    unawaited(_processQueue());
  }

  /// Pauses an active download while preserving partial `.part` bytes on disk for Range resume.
  Future<void> pauseDownload(String trackId) async {
    final CancelToken? token = _cancelTokens.remove(trackId);
    token?.cancel('Paused by user');

    final DownloadTaskItem? current = _tasks[trackId];
    if (current != null && !current.isCompleted) {
      final DownloadTaskItem paused = current.copyWith(status: DownloadStatus.paused);
      _tasks[trackId] = paused;
      await _localDatabase.saveDownloadTask(paused);
      _emitTasks();
    }
  }

  /// Resumes a paused download using HTTP Range headers (`bytes=<downloaded>-`).
  Future<void> resumeDownload(String trackId) async {
    final DownloadTaskItem? current = _tasks[trackId];
    if (current == null || current.isCompleted) return;

    final DownloadTaskItem queued = current.copyWith(
      status: DownloadStatus.queued,
      errorMessage: null,
    );
    _tasks[trackId] = queued;
    await _localDatabase.saveDownloadTask(queued);
    _emitTasks();
    unawaited(_processQueue());
  }

  /// Retries a failed download from scratch or from its partial file.
  Future<void> retryDownload(String trackId) async {
    await resumeDownload(trackId);
  }

  /// Deletes both the downloaded audio file (and `.part` file) and its task entry.
  Future<void> deleteDownload(String trackId) async {
    final CancelToken? token = _cancelTokens.remove(trackId);
    token?.cancel('Deleted by user');

    final DownloadTaskItem? task = _tasks.remove(trackId);
    if (task?.localPath != null) {
      final File completedFile = File(task!.localPath!);
      if (completedFile.existsSync()) {
        await completedFile.delete();
      }
      final File partFile = File('${task.localPath!}.part');
      if (partFile.existsSync()) {
        await partFile.delete();
      }
    }

    await _localDatabase.removeDownloadTask(trackId);
    _emitTasks();
  }

  /// Computes total disk bytes used by all completed and partial offline downloads.
  Future<int> getDownloadedStorageBytes() async {
    try {
      final Directory dir = await _getDownloadsDirectory();
      if (!dir.existsSync()) return 0;

      int totalBytes = 0;
      await for (final FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
      return totalBytes;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (true) {
        final DownloadTaskItem? nextTask = _tasks.values
            .cast<DownloadTaskItem?>()
            .firstWhere(
              (DownloadTaskItem? item) => item?.status == DownloadStatus.queued,
              orElse: () => null,
            );

        if (nextTask == null) break;
        await _executeChunkedDownload(nextTask);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _executeChunkedDownload(DownloadTaskItem task) async {
    final String trackId = task.track.id;
    final String targetPath = task.localPath ?? await _resolveTargetFilePath(task.track);
    final File partFile = File('$targetPath.part');
    final File finalFile = File(targetPath);

    int existingBytes = 0;
    if (partFile.existsSync()) {
      existingBytes = await partFile.length();
    }

    final CancelToken cancelToken = CancelToken();
    _cancelTokens[trackId] = cancelToken;

    DownloadTaskItem activeState = task.copyWith(
      status: DownloadStatus.downloading,
      localPath: targetPath,
      bytesDownloaded: existingBytes,
      errorMessage: null,
    );
    _tasks[trackId] = activeState;
    await _localDatabase.saveDownloadTask(activeState);
    _emitTasks();

    try {
      final String downloadUrl = await _resolveSignedOrDirectUrl(task.track);
      final Map<String, dynamic> headers = <String, dynamic>{};
      if (existingBytes > 0) {
        headers['Range'] = 'bytes=$existingBytes-';
      }

      final Response<ResponseBody> response = await _dioClient.rawDio.get<ResponseBody>(
        downloadUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
        ),
      );

      final int statusCode = response.statusCode ?? 200;
      // If server ignored Range header and sent 200 OK instead of 206 Partial Content, overwrite from 0
      final bool isPartial = statusCode == 206;
      if (!isPartial && existingBytes > 0) {
        existingBytes = 0;
      }

      final String? contentLengthHeader = response.headers.value(Headers.contentLengthHeader);
      final int remainingBytes = int.tryParse(contentLengthHeader ?? '') ?? 0;
      final int totalBytes = remainingBytes > 0 ? (existingBytes + remainingBytes) : 0;

      final RandomAccessFile raf = await partFile.open(
        mode: isPartial ? FileMode.append : FileMode.write,
      );

      int received = existingBytes;
      DateTime lastEmit = DateTime.now();

      try {
        final Stream<List<int>>? stream = response.data?.stream;
        if (stream != null) {
          await for (final List<int> chunk in stream) {
            if (cancelToken.isCancelled) break;
            await raf.writeFrom(chunk);
            received += chunk.length;

            final DateTime now = DateTime.now();
            if (now.difference(lastEmit).inMilliseconds >= 120) {
              lastEmit = now;
              final double progress = totalBytes > 0
                  ? (received / totalBytes).clamp(0.0, 0.99)
                  : 0.5;
              activeState = activeState.copyWith(
                bytesDownloaded: received,
                totalBytes: totalBytes,
                progress: progress,
              );
              _tasks[trackId] = activeState;
              _emitTasks();
            }
          }
        }
      } finally {
        await raf.close();
      }

      if (cancelToken.isCancelled) {
        return;
      }

      if (finalFile.existsSync()) {
        await finalFile.delete();
      }
      await partFile.rename(finalFile.path);

      final Track downloadedTrack = task.track.copyWith(
        isDownloaded: true,
        localFilePath: finalFile.path,
      );

      final DownloadTaskItem completedState = activeState.copyWith(
        track: downloadedTrack,
        status: DownloadStatus.completed,
        progress: 1.0,
        bytesDownloaded: received,
        totalBytes: received,
        localPath: finalFile.path,
      );

      _tasks[trackId] = completedState;
      await _localDatabase.saveDownloadTask(completedState);
      await _localDatabase.upsertLocalTrack(downloadedTrack);
      _emitTasks();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return;
      }
      AppLogger.error('Download failed for ${task.track.title}', error: e);
      final DownloadTaskItem failedState = activeState.copyWith(
        status: DownloadStatus.failed,
        errorMessage: 'Network interrupted. Tap retry to resume.',
      );
      _tasks[trackId] = failedState;
      await _localDatabase.saveDownloadTask(failedState);
      _emitTasks();
    } catch (e) {
      AppLogger.error('Unexpected download error for ${task.track.title}', error: e);
      final DownloadTaskItem failedState = activeState.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      _tasks[trackId] = failedState;
      await _localDatabase.saveDownloadTask(failedState);
      _emitTasks();
    } finally {
      _cancelTokens.remove(trackId);
    }
  }

  Future<String> _resolveSignedOrDirectUrl(Track track) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dioClient.post<Map<String, dynamic>>(
        '/downloads/sign',
        data: <String, dynamic>{
          'trackId': track.id,
          'source': track.source.value,
          'externalId': track.externalId,
          'downloadUrl': track.downloadUrl ?? track.streamUrl,
        },
      );
      final Map<String, dynamic>? body = response.data;
      final Map<String, dynamic>? dataObj =
          (body?['data'] is Map<String, dynamic>) ? body!['data'] as Map<String, dynamic> : body;
      final String? signedUrl = dataObj?['signedUrl'] as String? ?? dataObj?['url'] as String?;
      if (signedUrl != null && signedUrl.isNotEmpty) {
        return signedUrl;
      }
    } catch (_) {
      // Fallback to direct Creative Commons stream/download URL when offline or serverless
    }

    return track.downloadUrl ??
        track.streamUrl ??
        'https://archive.org/download/Synthetik-Ambient/01-Aurora.mp3';
  }

  Future<Directory> _getDownloadsDirectory() async {
    final Directory appSupport = await getApplicationSupportDirectory();
    final Directory dir = Directory(p.join(appSupport.path, 'anni_offline_downloads'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _resolveTargetFilePath(Track track) async {
    final Directory dir = await _getDownloadsDirectory();
    final String safeId = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final String ext = track.qualityBadge.toUpperCase().contains('FLAC') ? '.flac' : '.mp3';
    return p.join(dir.path, '$safeId$ext');
  }

  void _emitTasks() {
    if (!_tasksStreamController.isClosed) {
      _tasksStreamController.add(_tasks.values.toList());
    }
  }
}
