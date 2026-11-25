import 'package:flutter_test/flutter_test.dart';
import 'package:orsofey_downloader/core/models/app_settings.dart';
import 'package:orsofey_downloader/core/models/download_task.dart';
import 'package:orsofey_downloader/core/models/media_info.dart';
import 'package:orsofey_downloader/core/services/app_controller.dart';
import 'package:orsofey_downloader/core/services/cookie_store.dart';
import 'package:orsofey_downloader/core/services/download_engine.dart';
import 'package:orsofey_downloader/core/services/local_store.dart';

class _MemoryStore extends LocalStore {
  @override
  Future<LocalState> load() async =>
      const LocalState(settings: AppSettings(), tasks: []);

  @override
  Future<void> save(AppSettings settings, List<DownloadTask> tasks) async {}
}

class _FakeEngine implements DownloadEngine {
  bool playlist = false;

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
  }) async {
    return MediaInfo(
      id: 'media',
      title: playlist ? 'Плейлист' : 'Видео',
      webpageUrl: url,
      source: MediaSource.youtube,
      entries: playlist
          ? const [
              MediaEntry(index: 1, title: 'Первое', url: 'https://youtu.be/1'),
              MediaEntry(index: 2, title: 'Второе', url: 'https://youtu.be/2'),
            ]
          : const [],
    );
  }

  @override
  Future<String> download(
    DownloadJob job, {
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    onProgress(const DownloadProgress(fraction: 0.5));
    onProgress(const DownloadProgress(fraction: 1));
    return 'downloads/${job.taskId}.mp4';
  }

  @override
  Future<void> stop(String taskId) async {}

  @override
  Future<void> updateEngine() async {}
}

AppController _controller(_FakeEngine engine) => AppController(
  engine: engine,
  store: _MemoryStore(),
  cookies: CookieStore(),
);

Future<List<DownloadTask>> _enqueue(AppController controller) =>
    controller.enqueue(
      kind: DownloadKind.video,
      quality: 1080,
      container: 'mp4',
      audioBitrate: 192,
      thumbnailMode: ThumbnailMode.none,
      writeSubtitles: false,
      autoSubtitles: false,
      embedSubtitles: false,
      subtitleLanguages: 'ru,en',
    );

void main() {
  test('одиночное видео проходит путь от анализа до истории', () async {
    final engine = _FakeEngine();
    final controller = _controller(engine);
    await controller.initialize();
    await controller.analyze('https://youtu.be/abc');

    expect(controller.preview?.title, 'Видео');
    final created = await _enqueue(controller);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(created, hasLength(1));
    expect(controller.tasks.single.status, DownloadStatus.completed);
    expect(controller.tasks.single.progress, 1);
    expect(controller.historyTasks, hasLength(1));
    expect(controller.activeTasks, isEmpty);
  });

  test('плейлист добавляет выбранные элементы отдельными задачами', () async {
    final engine = _FakeEngine()..playlist = true;
    final controller = _controller(engine);
    await controller.initialize();
    await controller.analyze('https://youtube.com/playlist?list=abc');
    controller.togglePlaylistEntry(2);

    final created = await _enqueue(controller);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(created, hasLength(1));
    expect(created.single.title, 'Первое');
    expect(created.single.playlistItems, [1]);
    expect(controller.historyTasks, hasLength(1));
  });

  test(
    'некорректная ссылка показывает локальную ошибку без запуска движка',
    () async {
      final controller = _controller(_FakeEngine());
      await controller.initialize();
      await controller.analyze('https://example.com/video');

      expect(controller.preview, isNull);
      expect(controller.inspectError, contains('Поддерживаются'));
      expect(controller.analyzing, isFalse);
    },
  );

  test('copyWith очищает ошибку и сетевые показатели явно', () {
    final task = DownloadTask(
      id: '1',
      url: 'https://youtu.be/abc',
      title: 'Test',
      source: MediaSource.youtube,
      kind: DownloadKind.video,
      quality: 1080,
      container: 'mp4',
      audioBitrate: 192,
      createdAt: DateTime(2026),
      status: DownloadStatus.failed,
      error: 'network',
      speed: 100,
      etaSeconds: 30,
    );

    final retried = task.copyWith(
      status: DownloadStatus.queued,
      clearError: true,
      clearNetworkStats: true,
    );
    expect(retried.error, isNull);
    expect(retried.speed, isNull);
    expect(retried.etaSeconds, isNull);
  });
}
