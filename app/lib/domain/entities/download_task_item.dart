import 'package:equatable/equatable.dart';
import 'track.dart';

/// Lifecycle status of an offline audio download task.
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed;

  static DownloadStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'queued':
        return DownloadStatus.queued;
      case 'downloading':
        return DownloadStatus.downloading;
      case 'paused':
        return DownloadStatus.paused;
      case 'completed':
        return DownloadStatus.completed;
      case 'failed':
        return DownloadStatus.failed;
      default:
        return DownloadStatus.queued;
    }
  }
}

/// Represents a track download task managed by the chunked HTTP Range downloader.
class DownloadTaskItem extends Equatable {
  const DownloadTaskItem({
    required this.track,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.localPath,
    this.errorMessage,
  });

  final Track track;
  final double progress;
  final DownloadStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final String? localPath;
  final String? errorMessage;

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isFailed => status == DownloadStatus.failed;

  String get formattedSizeProgress {
    if (totalBytes <= 0) {
      final double mb = bytesDownloaded / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
    final double downMb = bytesDownloaded / (1024 * 1024);
    final double totalMb = totalBytes / (1024 * 1024);
    return '${downMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB';
  }

  DownloadTaskItem copyWith({
    Track? track,
    double? progress,
    DownloadStatus? status,
    int? bytesDownloaded,
    int? totalBytes,
    String? localPath,
    String? errorMessage,
  }) {
    return DownloadTaskItem(
      track: track ?? this.track,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'track': track.toJson(),
      'progress': progress,
      'status': status.name,
      'bytesDownloaded': bytesDownloaded,
      'totalBytes': totalBytes,
      'localPath': localPath,
      'errorMessage': errorMessage,
    };
  }

  factory DownloadTaskItem.fromJson(Map<String, dynamic> json) {
    return DownloadTaskItem(
      track: Track.fromJson(
        (json['track'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: DownloadStatus.fromString(json['status'] as String?),
      bytesDownloaded: (json['bytesDownloaded'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      localPath: json['localPath'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        track,
        progress,
        status,
        bytesDownloaded,
        totalBytes,
        localPath,
        errorMessage,
      ];
}
