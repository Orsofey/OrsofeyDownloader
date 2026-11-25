import 'media_info.dart';

enum DownloadStatus {
  queued,
  downloading,
  processing,
  paused,
  completed,
  failed,
  canceled;

  bool get isActive =>
      this == DownloadStatus.queued ||
      this == DownloadStatus.downloading ||
      this == DownloadStatus.processing;

  bool get isFinished =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.canceled;

  String get label => switch (this) {
    DownloadStatus.queued => 'В очереди',
    DownloadStatus.downloading => 'Загрузка',
    DownloadStatus.processing => 'Обработка',
    DownloadStatus.paused => 'Пауза',
    DownloadStatus.completed => 'Готово',
    DownloadStatus.failed => 'Ошибка',
    DownloadStatus.canceled => 'Отменено',
  };

  static DownloadStatus fromName(String? value) {
    return DownloadStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => DownloadStatus.queued,
    );
  }
}

class DownloadProgress {
  const DownloadProgress({
    this.fraction,
    this.downloadedBytes,
    this.totalBytes,
    this.speed,
    this.etaSeconds,
    this.stage,
  });

  final double? fraction;
  final int? downloadedBytes;
  final int? totalBytes;
  final double? speed;
  final int? etaSeconds;
  final DownloadStatus? stage;
}

class DownloadJob {
  const DownloadJob({
    required this.taskId,
    required this.url,
    required this.directory,
    required this.kind,
    required this.quality,
    required this.container,
    required this.audioBitrate,
    required this.thumbnailMode,
    required this.writeSubtitles,
    required this.autoSubtitles,
    required this.embedSubtitles,
    required this.subtitleLanguages,
    this.cookiesFile,
    this.cookiesFromBrowser,
    this.playlistItems,
  });

  final String taskId;
  final String url;
  final String directory;
  final DownloadKind kind;
  final int quality;
  final String container;
  final int audioBitrate;
  final ThumbnailMode thumbnailMode;
  final bool writeSubtitles;
  final bool autoSubtitles;
  final bool embedSubtitles;
  final String subtitleLanguages;
  final String? cookiesFile;
  final String? cookiesFromBrowser;
  final List<int>? playlistItems;
}

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.source,
    required this.kind,
    required this.quality,
    required this.container,
    required this.audioBitrate,
    required this.createdAt,
    this.thumbnailUrl,
    this.uploader,
    this.duration,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.speed,
    this.etaSeconds,
    this.downloadedBytes,
    this.totalBytes,
    this.filePath,
    this.error,
    this.completedAt,
    this.thumbnailMode = ThumbnailMode.separate,
    this.writeSubtitles = false,
    this.autoSubtitles = false,
    this.embedSubtitles = false,
    this.subtitleLanguages = 'ru,en',
    this.playlistTitle,
    this.playlistItems,
  });

  final String id;
  final String url;
  final String title;
  final MediaSource source;
  final DownloadKind kind;
  final int quality;
  final String container;
  final int audioBitrate;
  final DateTime createdAt;
  final String? thumbnailUrl;
  final String? uploader;
  final num? duration;
  final DownloadStatus status;
  final double progress;
  final double? speed;
  final int? etaSeconds;
  final int? downloadedBytes;
  final int? totalBytes;
  final String? filePath;
  final String? error;
  final DateTime? completedAt;
  final ThumbnailMode thumbnailMode;
  final bool writeSubtitles;
  final bool autoSubtitles;
  final bool embedSubtitles;
  final String subtitleLanguages;
  final String? playlistTitle;
  final List<int>? playlistItems;

  String get qualityLabel => kind == DownloadKind.audio
      ? 'MP3 · $audioBitrate кбит/с'
      : quality <= 0
      ? 'Лучшее · ${container.toUpperCase()}'
      : '${quality}p · ${container.toUpperCase()}';

  DownloadTask copyWith({
    String? title,
    String? thumbnailUrl,
    String? uploader,
    num? duration,
    DownloadStatus? status,
    double? progress,
    double? speed,
    int? etaSeconds,
    int? downloadedBytes,
    int? totalBytes,
    String? filePath,
    String? error,
    DateTime? completedAt,
    String? playlistTitle,
    List<int>? playlistItems,
    bool clearError = false,
    bool clearNetworkStats = false,
    bool clearCompletedAt = false,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      title: title ?? this.title,
      source: source,
      kind: kind,
      quality: quality,
      container: container,
      audioBitrate: audioBitrate,
      createdAt: createdAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploader: uploader ?? this.uploader,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: clearNetworkStats ? null : speed ?? this.speed,
      etaSeconds: clearNetworkStats ? null : etaSeconds ?? this.etaSeconds,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      error: clearError ? null : error ?? this.error,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      thumbnailMode: thumbnailMode,
      writeSubtitles: writeSubtitles,
      autoSubtitles: autoSubtitles,
      embedSubtitles: embedSubtitles,
      subtitleLanguages: subtitleLanguages,
      playlistTitle: playlistTitle ?? this.playlistTitle,
      playlistItems: playlistItems ?? this.playlistItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'source': source.name,
    'kind': kind.name,
    'quality': quality,
    'container': container,
    'audioBitrate': audioBitrate,
    'createdAt': createdAt.toIso8601String(),
    'thumbnailUrl': thumbnailUrl,
    'uploader': uploader,
    'duration': duration,
    'status': status.name,
    'progress': progress,
    'speed': speed,
    'etaSeconds': etaSeconds,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'filePath': filePath,
    'error': error,
    'completedAt': completedAt?.toIso8601String(),
    'thumbnailMode': thumbnailMode.name,
    'writeSubtitles': writeSubtitles,
    'autoSubtitles': autoSubtitles,
    'embedSubtitles': embedSubtitles,
    'subtitleLanguages': subtitleLanguages,
    'playlistTitle': playlistTitle,
    'playlistItems': playlistItems,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Без названия',
      source: MediaSource.fromName(json['source']?.toString()),
      kind: DownloadKind.fromName(json['kind']?.toString()),
      quality: (json['quality'] as num?)?.toInt() ?? 1080,
      container: json['container']?.toString() ?? 'mp4',
      audioBitrate: (json['audioBitrate'] as num?)?.toInt() ?? 192,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      uploader: json['uploader']?.toString(),
      duration: json['duration'] as num?,
      status: DownloadStatus.fromName(json['status']?.toString()),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble(),
      etaSeconds: (json['etaSeconds'] as num?)?.toInt(),
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt(),
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      filePath: json['filePath']?.toString(),
      error: json['error']?.toString(),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      thumbnailMode: ThumbnailMode.fromName(json['thumbnailMode']?.toString()),
      writeSubtitles: json['writeSubtitles'] == true,
      autoSubtitles: json['autoSubtitles'] == true,
      embedSubtitles: json['embedSubtitles'] == true,
      subtitleLanguages: json['subtitleLanguages']?.toString() ?? 'ru,en',
      playlistTitle: json['playlistTitle']?.toString(),
      playlistItems: (json['playlistItems'] as List?)
          ?.whereType<num>()
          .map((item) => item.toInt())
          .toList(),
    );
  }
}
