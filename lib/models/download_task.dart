enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.title,
    this.posterUrl,
    this.movieId,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.status = DownloadStatus.queued,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String url;
  String fileName;
  String savePath;
  final String? title;
  final String? posterUrl;
  final String? movieId;
  final DateTime createdAt;
  int totalBytes;
  int receivedBytes;
  DownloadStatus status;
  String? error;

  /// Smoothed bytes per second while downloading. Not persisted.
  double speed = 0;

  String get displayTitle => title ?? fileName;

  bool get isActive =>
      status == DownloadStatus.downloading || status == DownloadStatus.queued;

  double? get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  Duration? get eta {
    if (speed < 1 || totalBytes <= 0) return null;
    return Duration(seconds: ((totalBytes - receivedBytes) / speed).round());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'fileName': fileName,
    'savePath': savePath,
    'title': title,
    'posterUrl': posterUrl,
    'movieId': movieId,
    'totalBytes': totalBytes,
    'receivedBytes': receivedBytes,
    'status': status.name,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DownloadTask.fromJson(Map<String, dynamic> j) => DownloadTask(
    id: j['id'] as String,
    url: j['url'] as String,
    fileName: j['fileName'] as String,
    savePath: j['savePath'] as String,
    title: j['title'] as String?,
    posterUrl: j['posterUrl'] as String?,
    movieId: j['movieId'] as String?,
    totalBytes: j['totalBytes'] as int? ?? 0,
    receivedBytes: j['receivedBytes'] as int? ?? 0,
    status:
        DownloadStatus.values.asNameMap()[j['status']] ?? DownloadStatus.paused,
    error: j['error'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
  );
}
