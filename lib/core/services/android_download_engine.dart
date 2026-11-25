import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/download_task.dart';
import '../models/media_info.dart';
import '../utils/url_parser.dart';
import 'download_engine.dart';

class AndroidDownloadEngine implements DownloadEngine {
  AndroidDownloadEngine() {
    _events = const EventChannel('com.orsofey.downloader/events')
        .receiveBroadcastStream()
        .map((event) {
          final map = Map<String, dynamic>.from(event as Map);
          return _AndroidProgressEvent.fromMap(map);
        });
  }

  static const _channel = MethodChannel('com.orsofey.downloader/engine');
  late final Stream<_AndroidProgressEvent> _events;

  @override
  Future<EngineStatus> getStatus() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      return EngineStatus(
        available: result?['available'] == true,
        version: result?['version']?.toString() ?? '—',
        description:
            result?['description']?.toString() ?? 'Локальный Android-движок',
      );
    } on PlatformException catch (error) {
      return EngineStatus(
        available: false,
        version: '—',
        description: error.message ?? 'Движок недоступен',
      );
    }
  }

  @override
  Future<String> getDefaultDownloadDirectory() async {
    final result = await _channel.invokeMethod<String>('getDownloadDirectory');
    if (result == null || result.isEmpty) {
      throw const DownloadException('Не удалось определить папку загрузок');
    }
    return result;
  }

  @override
  Future<MediaInfo> inspect(
    String url, {
    String? cookiesFile,
    String? cookiesFromBrowser,
  }) async {
    try {
      final json = await _channel.invokeMethod<String>('inspect', {
        'url': url,
        'cookiesFile': cookiesFile,
      });
      if (json == null || json.isEmpty) {
        throw const DownloadException('Площадка вернула пустой ответ');
      }
      final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
      final parsed = parseSupportedLink(url);
      return MediaInfo.fromYtDlpJson(
        map,
        parsed?.source ?? MediaSource.unknown,
      );
    } on PlatformException catch (error) {
      throw DownloadException(
        friendlyEngineError(error.message ?? ''),
        error.details?.toString() ?? '',
      );
    } on FormatException catch (error) {
      throw DownloadException(
        'Не удалось прочитать информацию о видео',
        error.message,
      );
    }
  }

  @override
  Future<String> download(
    DownloadJob job, {
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    final subscription = _events
        .where((event) => event.taskId == job.taskId)
        .listen((event) => onProgress(event.progress));
    try {
      final result = await _channel.invokeMethod<String>('download', {
        'taskId': job.taskId,
        'url': job.url,
        'directory': job.directory,
        'kind': job.kind.name,
        'quality': job.quality,
        'container': job.container,
        'audioBitrate': job.audioBitrate,
        'thumbnailMode': job.thumbnailMode.name,
        'writeSubtitles': job.writeSubtitles,
        'autoSubtitles': job.autoSubtitles,
        'embedSubtitles': job.embedSubtitles,
        'subtitleLanguages': job.subtitleLanguages,
        'cookiesFile': job.cookiesFile,
        'playlistItems': job.playlistItems?.join(','),
      });
      return result ?? '';
    } on PlatformException catch (error) {
      if (error.code == 'STOPPED') throw const DownloadStoppedException();
      throw DownloadException(
        friendlyEngineError(error.message ?? ''),
        error.details?.toString() ?? '',
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> stop(String taskId) async {
    await _channel.invokeMethod<void>('stop', {'taskId': taskId});
  }

  @override
  Future<void> updateEngine() async {
    try {
      await _channel.invokeMethod<void>('updateEngine');
    } on PlatformException catch (error) {
      throw DownloadException(
        friendlyEngineError(error.message ?? ''),
        error.details?.toString() ?? '',
      );
    }
  }
}

class _AndroidProgressEvent {
  const _AndroidProgressEvent({required this.taskId, required this.progress});

  final String taskId;
  final DownloadProgress progress;

  factory _AndroidProgressEvent.fromMap(Map<String, dynamic> map) {
    return _AndroidProgressEvent(
      taskId: map['taskId']?.toString() ?? '',
      progress: DownloadProgress(
        fraction: (map['fraction'] as num?)?.toDouble(),
        downloadedBytes: (map['downloadedBytes'] as num?)?.toInt(),
        totalBytes: (map['totalBytes'] as num?)?.toInt(),
        speed: (map['speed'] as num?)?.toDouble(),
        etaSeconds: (map['etaSeconds'] as num?)?.toInt(),
        stage: map['stage'] == 'processing'
            ? DownloadStatus.processing
            : DownloadStatus.downloading,
      ),
    );
  }
}

String friendlyEngineError(String raw) {
  final message = raw.toLowerCase();
  if (message.contains('sign in') ||
      message.contains('private') ||
      message.contains('login') ||
      message.contains('cookies')) {
    return 'Видео требует авторизации. Добавьте cookies в настройках.';
  }
  if (message.contains('ip address is blocked') ||
      message.contains('blocked from accessing')) {
    return 'Площадка блокирует этот IP или регион. Попробуйте другую сеть или VPN, если это допустимо.';
  }
  if (message.contains('429') || message.contains('too many requests')) {
    return 'Площадка временно ограничила запросы. Попробуйте позже.';
  }
  if (message.contains('unsupported url')) {
    return 'Эта ссылка пока не поддерживается движком.';
  }
  if (message.contains('unavailable') || message.contains('not found')) {
    return 'Видео недоступно или было удалено.';
  }
  if (message.contains('no space')) {
    return 'Недостаточно свободного места для загрузки.';
  }
  if (message.contains('network') ||
      message.contains('timed out') ||
      message.contains('connection') ||
      message.contains('getaddrinfo') ||
      message.contains('failed to resolve') ||
      message.contains('name or service not known')) {
    return 'Проблема с соединением. Проверьте интернет и повторите.';
  }
  if (message.contains('javascript') || message.contains('js runtime')) {
    return 'Нужно обновить компоненты загрузчика в настройках.';
  }
  if (message.contains('format')) {
    return 'Выбранный формат недоступен. Попробуйте другое качество.';
  }
  return raw.trim().isEmpty
      ? 'Не удалось выполнить загрузку. Повторите попытку.'
      : raw.trim();
}
