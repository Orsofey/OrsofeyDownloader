enum MediaSource {
  youtube,
  tiktok,
  vk,
  unknown;

  String get label => switch (this) {
    MediaSource.youtube => 'YouTube',
    MediaSource.tiktok => 'TikTok',
    MediaSource.vk => 'VK Видео',
    MediaSource.unknown => 'Другое',
  };

  String get shortLabel => switch (this) {
    MediaSource.youtube => 'YT',
    MediaSource.tiktok => 'TT',
    MediaSource.vk => 'VK',
    MediaSource.unknown => '—',
  };

  static MediaSource fromName(String? value) {
    return MediaSource.values.firstWhere(
      (item) => item.name == value,
      orElse: () => MediaSource.unknown,
    );
  }
}

enum DownloadKind {
  video,
  audio;

  String get label => this == DownloadKind.video ? 'Видео' : 'Только звук';

  static DownloadKind fromName(String? value) {
    return DownloadKind.values.firstWhere(
      (item) => item.name == value,
      orElse: () => DownloadKind.video,
    );
  }
}

enum ThumbnailMode {
  none,
  separate,
  embed;

  static ThumbnailMode fromName(String? value) {
    return ThumbnailMode.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ThumbnailMode.separate,
    );
  }
}

class MediaFormat {
  const MediaFormat({
    required this.id,
    this.height,
    this.width,
    this.fps,
    this.ext = 'mp4',
    this.fileSize,
    this.videoCodec,
    this.audioCodec,
  });

  final String id;
  final int? height;
  final int? width;
  final double? fps;
  final String ext;
  final int? fileSize;
  final String? videoCodec;
  final String? audioCodec;

  String get label {
    if (height == null) return ext.toUpperCase();
    final fpsLabel = fps != null && fps! > 30 ? ' · ${fps!.round()} fps' : '';
    return '${height}p$fpsLabel · ${ext.toUpperCase()}';
  }

  factory MediaFormat.fromMap(Map<String, dynamic> map) {
    final size = map['filesize'] ?? map['filesize_approx'];
    return MediaFormat(
      id: map['format_id']?.toString() ?? '',
      height: _asInt(map['height']),
      width: _asInt(map['width']),
      fps: _asDouble(map['fps']),
      ext: map['ext']?.toString() ?? 'mp4',
      fileSize: size is num ? size.toInt() : null,
      videoCodec: map['vcodec']?.toString(),
      audioCodec: map['acodec']?.toString(),
    );
  }
}

class MediaEntry {
  const MediaEntry({
    required this.index,
    required this.title,
    required this.url,
    this.id,
    this.duration,
    this.thumbnailUrl,
  });

  final int index;
  final String title;
  final String url;
  final String? id;
  final num? duration;
  final String? thumbnailUrl;

  factory MediaEntry.fromMap(Map<String, dynamic> map, int index) {
    final thumbnails = map['thumbnails'];
    String? thumbnail = map['thumbnail']?.toString();
    if (thumbnail == null && thumbnails is List && thumbnails.isNotEmpty) {
      final last = thumbnails.last;
      if (last is Map) thumbnail = last['url']?.toString();
    }
    final url = map['webpage_url'] ?? map['url'] ?? map['original_url'];
    return MediaEntry(
      index: index + 1,
      title: map['title']?.toString() ?? 'Видео ${index + 1}',
      url: url?.toString() ?? '',
      id: map['id']?.toString(),
      duration: map['duration'] as num?,
      thumbnailUrl: thumbnail,
    );
  }
}

class MediaInfo {
  const MediaInfo({
    required this.id,
    required this.title,
    required this.webpageUrl,
    required this.source,
    this.uploader,
    this.duration,
    this.thumbnailUrl,
    this.description,
    this.formats = const [],
    this.entries = const [],
  });

  final String id;
  final String title;
  final String webpageUrl;
  final MediaSource source;
  final String? uploader;
  final num? duration;
  final String? thumbnailUrl;
  final String? description;
  final List<MediaFormat> formats;
  final List<MediaEntry> entries;

  bool get isPlaylist => entries.isNotEmpty;

  List<int> get availableHeights {
    final heights =
        formats
            .map((format) => format.height)
            .whereType<int>()
            .where((height) => height > 0)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return heights;
  }

  int? estimatedSize(int quality, String extension) {
    final audioSize = formats
        .where(
          (format) =>
              format.fileSize != null &&
              (format.videoCodec == null || format.videoCodec == 'none') &&
              (format.audioCodec != null && format.audioCodec != 'none'),
        )
        .fold<int>(0, (best, format) {
          final size = format.fileSize!;
          return size > best ? size : best;
        });

    final candidates = formats.where((format) {
      if (format.fileSize == null || format.height == null) return false;
      if (quality > 0 && format.height != quality) return false;
      if (format.videoCodec == 'none') return false;
      return true;
    }).toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aPreferred = a.ext == extension ? 1 : 0;
      final bPreferred = b.ext == extension ? 1 : 0;
      if (aPreferred != bPreferred) {
        return bPreferred.compareTo(aPreferred);
      }
      if (quality <= 0 && a.height != b.height) {
        return b.height!.compareTo(a.height!);
      }
      return b.fileSize!.compareTo(a.fileSize!);
    });
    final videoSize = candidates.first.fileSize!;
    return audioSize > 0 ? videoSize + audioSize : videoSize;
  }

  List<String> get availableVideoExtensions {
    final values =
        formats
            .where((format) => format.height != null)
            .map((format) => format.ext.toLowerCase())
            .where((ext) => ext == 'mp4' || ext == 'webm')
            .toSet()
            .toList()
          ..sort();
    return values.isEmpty ? const ['mp4'] : values;
  }

  factory MediaInfo.fromYtDlpJson(
    Map<String, dynamic> map,
    MediaSource source,
  ) {
    final thumbnails = map['thumbnails'];
    String? thumbnail = map['thumbnail']?.toString();
    if (thumbnail == null && thumbnails is List && thumbnails.isNotEmpty) {
      final last = thumbnails.last;
      if (last is Map) thumbnail = last['url']?.toString();
    }

    final rawFormats = map['formats'];
    final formats = rawFormats is List
        ? rawFormats
              .whereType<Map>()
              .map(
                (item) => MediaFormat.fromMap(Map<String, dynamic>.from(item)),
              )
              .where((format) => format.id.isNotEmpty)
              .toList()
        : <MediaFormat>[];

    final rawEntries = map['entries'];
    final entries = rawEntries is List
        ? rawEntries
              .whereType<Map>()
              .map(
                (item) => MediaEntry.fromMap(
                  Map<String, dynamic>.from(item),
                  rawEntries.indexOf(item),
                ),
              )
              .where((entry) => entry.url.isNotEmpty)
              .toList()
        : <MediaEntry>[];

    return MediaInfo(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Без названия',
      webpageUrl:
          map['webpage_url']?.toString() ??
          map['original_url']?.toString() ??
          map['url']?.toString() ??
          '',
      source: source,
      uploader:
          map['uploader']?.toString() ??
          map['channel']?.toString() ??
          map['uploader_id']?.toString(),
      duration: map['duration'] as num?,
      thumbnailUrl: thumbnail,
      description: map['description']?.toString(),
      formats: formats,
      entries: entries,
    );
  }
}

int? _asInt(dynamic value) => value is num ? value.toInt() : null;
double? _asDouble(dynamic value) => value is num ? value.toDouble() : null;
