import 'media_info.dart';

class AppSettings {
  const AppSettings({
    this.downloadDirectory = '',
    this.defaultKind = DownloadKind.video,
    this.defaultQuality = 1080,
    this.videoContainer = 'mp4',
    this.audioBitrate = 192,
    this.thumbnailMode = ThumbnailMode.separate,
    this.writeSubtitles = false,
    this.autoSubtitles = false,
    this.embedSubtitles = false,
    this.subtitleLanguages = 'ru,en',
    this.maxConcurrent = 2,
    this.cookiesBrowser = '',
    this.hasCookies = false,
    this.checkEngineUpdates = true,
  });

  final String downloadDirectory;
  final DownloadKind defaultKind;
  final int defaultQuality;
  final String videoContainer;
  final int audioBitrate;
  final ThumbnailMode thumbnailMode;
  final bool writeSubtitles;
  final bool autoSubtitles;
  final bool embedSubtitles;
  final String subtitleLanguages;
  final int maxConcurrent;
  final String cookiesBrowser;
  final bool hasCookies;
  final bool checkEngineUpdates;

  AppSettings copyWith({
    String? downloadDirectory,
    DownloadKind? defaultKind,
    int? defaultQuality,
    String? videoContainer,
    int? audioBitrate,
    ThumbnailMode? thumbnailMode,
    bool? writeSubtitles,
    bool? autoSubtitles,
    bool? embedSubtitles,
    String? subtitleLanguages,
    int? maxConcurrent,
    String? cookiesBrowser,
    bool? hasCookies,
    bool? checkEngineUpdates,
  }) {
    return AppSettings(
      downloadDirectory: downloadDirectory ?? this.downloadDirectory,
      defaultKind: defaultKind ?? this.defaultKind,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      videoContainer: videoContainer ?? this.videoContainer,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      thumbnailMode: thumbnailMode ?? this.thumbnailMode,
      writeSubtitles: writeSubtitles ?? this.writeSubtitles,
      autoSubtitles: autoSubtitles ?? this.autoSubtitles,
      embedSubtitles: embedSubtitles ?? this.embedSubtitles,
      subtitleLanguages: subtitleLanguages ?? this.subtitleLanguages,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      cookiesBrowser: cookiesBrowser ?? this.cookiesBrowser,
      hasCookies: hasCookies ?? this.hasCookies,
      checkEngineUpdates: checkEngineUpdates ?? this.checkEngineUpdates,
    );
  }

  Map<String, dynamic> toJson() => {
    'downloadDirectory': downloadDirectory,
    'defaultKind': defaultKind.name,
    'defaultQuality': defaultQuality,
    'videoContainer': videoContainer,
    'audioBitrate': audioBitrate,
    'thumbnailMode': thumbnailMode.name,
    'writeSubtitles': writeSubtitles,
    'autoSubtitles': autoSubtitles,
    'embedSubtitles': embedSubtitles,
    'subtitleLanguages': subtitleLanguages,
    'maxConcurrent': maxConcurrent,
    'cookiesBrowser': cookiesBrowser,
    'hasCookies': hasCookies,
    'checkEngineUpdates': checkEngineUpdates,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      downloadDirectory: json['downloadDirectory']?.toString() ?? '',
      defaultKind: DownloadKind.fromName(json['defaultKind']?.toString()),
      defaultQuality: (json['defaultQuality'] as num?)?.toInt() ?? 1080,
      videoContainer: json['videoContainer']?.toString() ?? 'mp4',
      audioBitrate: (json['audioBitrate'] as num?)?.toInt() ?? 192,
      thumbnailMode: ThumbnailMode.fromName(json['thumbnailMode']?.toString()),
      writeSubtitles: json['writeSubtitles'] == true,
      autoSubtitles: json['autoSubtitles'] == true,
      embedSubtitles: json['embedSubtitles'] == true,
      subtitleLanguages: json['subtitleLanguages']?.toString() ?? 'ru,en',
      maxConcurrent: ((json['maxConcurrent'] as num?)?.toInt() ?? 2).clamp(
        1,
        3,
      ),
      cookiesBrowser: json['cookiesBrowser']?.toString() ?? '',
      hasCookies: json['hasCookies'] == true,
      checkEngineUpdates: json['checkEngineUpdates'] != false,
    );
  }
}
