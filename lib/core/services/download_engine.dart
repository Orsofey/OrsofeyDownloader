import 'dart:io';

import '../models/download_task.dart';
import '../models/media_info.dart';
import 'android_download_engine.dart';
import 'yt_dlp_engine.dart';

class DownloadException implements Exception {
  const DownloadException(this.message, [this.details = '']);

  final String message;
  final String details;

  @override
  String toString() => details.isEmpty ? message : '$message\n$details';
}

class DownloadStoppedException implements Exception {
  const DownloadStoppedException();
}

class EngineStatus {
  const EngineStatus({
    required this.available,
    required this.version,
    required this.description,
  });

  final bool available;
  final String version;
  final String description;
}

abstract interface class DownloadEngine {
  Future<EngineStatus> getStatus();

  Future<String> getDefaultDownloadDirectory();

  Future<MediaInfo> inspect(
    String url, {
    String? cookiesFile,
    String? cookiesFromBrowser,
  });

  Future<String> download(
    DownloadJob job, {
    required void Function(DownloadProgress progress) onProgress,
  });

  Future<void> stop(String taskId);

  Future<void> updateEngine();
}

DownloadEngine createDownloadEngine() {
  if (Platform.isAndroid) return AndroidDownloadEngine();
  if (Platform.isWindows) return YtDlpEngine();
  throw UnsupportedError(
    'Платформа ${Platform.operatingSystem} не поддерживается',
  );
}
