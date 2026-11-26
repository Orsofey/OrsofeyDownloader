import 'package:flutter_test/flutter_test.dart';
import 'package:orsofey_downloader/core/services/android_download_engine.dart';
import 'package:orsofey_downloader/core/services/app_controller.dart';
import 'package:orsofey_downloader/core/services/cookie_store.dart';
import 'package:orsofey_downloader/core/models/app_settings.dart';
import 'package:orsofey_downloader/core/models/download_task.dart';
import 'package:orsofey_downloader/core/models/media_info.dart';
import 'package:orsofey_downloader/core/services/download_engine.dart';
import 'package:orsofey_downloader/core/services/local_store.dart';

class _Store extends LocalStore {
  @override
  Future<LocalState> load() async =>
      const LocalState(settings: AppSettings(), tasks: []);
  @override
  Future<void> save(AppSettings settings, List<DownloadTask> tasks) async {}
}

class _Engine implements DownloadEngine {
  @override
  Future<EngineStatus> getStatus() async =>
      const EngineStatus(available: true, version: 'test', description: 'test');
  @override
  Future<String> getDefaultDownloadDirectory() async => 'downloads';
  @override
  Future<MediaInfo> inspect(
    String url, {
    String? cookiesFile,
    String? cookiesFromBrowser,
  }) => throw UnimplementedError();
  @override
  Future<String> download(
    DownloadJob job, {
    required void Function(DownloadProgress progress) onProgress,
  }) => throw UnimplementedError();
  @override
  Future<void> stop(String taskId) async {}
  @override
  Future<void> updateEngine() async {}
}

void main() {
  test('HTTP 503 не отображается как удалённое видео', () {
    final message = friendlyEngineError(
      'ERROR: [download] Got error: HTTP Error 503: Service Unavailable. Giving up after 3 retries',
    );
    expect(message, contains('503'));
    expect(message, isNot(contains('удалено')));
  });

  test('openQueue запрашивает переход на экран очереди', () {
    final controller = AppController(
      engine: _Engine(),
      store: _Store(),
      cookies: CookieStore(),
    );
    expect(controller.navigationRequest, 0);
    controller.openQueue();
    expect(controller.navigationRequest, 1);
  });
}
