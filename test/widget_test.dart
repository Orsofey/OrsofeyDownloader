import 'package:flutter/material.dart' show Size;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:orsofey_downloader/app.dart';
import 'package:orsofey_downloader/core/models/app_settings.dart';
import 'package:orsofey_downloader/core/models/download_task.dart';
import 'package:orsofey_downloader/core/models/media_info.dart';
import 'package:orsofey_downloader/core/services/app_controller.dart';
import 'package:orsofey_downloader/core/services/cookie_store.dart';
import 'package:orsofey_downloader/core/services/download_engine.dart';
import 'package:orsofey_downloader/core/services/local_store.dart';

class _FakeEngine implements DownloadEngine {
  @override
  Future<EngineStatus> getStatus() async => const EngineStatus(
    available: true,
    version: 'test',
    description: 'Тестовый движок',
  );

  @override
  Future<String> getDefaultDownloadDirectory() async => 'test_downloads';

  @override
  Future<MediaInfo> inspect(
    String url, {
    String? cookiesFile,
    String? cookiesFromBrowser,
  }) async {
    return MediaInfo(
      id: 'test',
      title: 'Тестовое видео',
      webpageUrl: url,
      source: MediaSource.youtube,
    );
  }

  @override
  Future<String> download(
    DownloadJob job, {
    required void Function(DownloadProgress progress) onProgress,
  }) async {
    onProgress(const DownloadProgress(fraction: 1));
    return 'test_downloads/video.mp4';
  }

  @override
  Future<void> stop(String taskId) async {}

  @override
  Future<void> updateEngine() async {}
}

class _MemoryStore extends LocalStore {
  AppSettings? savedSettings;
  List<DownloadTask>? savedTasks;

  @override
  Future<LocalState> load() async =>
      const LocalState(settings: AppSettings(), tasks: []);

  @override
  Future<void> save(AppSettings settings, List<DownloadTask> tasks) async {
    savedSettings = settings;
    savedTasks = tasks;
  }
}

void main() {
  setUpAll(() async {
    final fontLoader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Manrope-Bold.ttf'));
    await fontLoader.load();
  });

  testWidgets('Главный экран отображает бренд и поле ссылки', (tester) async {
    final controller = AppController(
      engine: _FakeEngine(),
      store: _MemoryStore(),
      cookies: CookieStore(),
    );
    await tester.pumpWidget(AppRoot(controller: controller));
    await controller.initialize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Orsofey'), findsOneWidget);
    expect(find.text('Получить видео'), findsOneWidget);
    expect(find.text('Очередь'), findsOneWidget);
  });

  testWidgets('Рабочий стол: визуальный снимок главного экрана', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = AppController(
      engine: _FakeEngine(),
      store: _MemoryStore(),
      cookies: CookieStore(),
    );
    await tester.pumpWidget(AppRoot(controller: controller));
    await controller.initialize();
    await tester.pump();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MainShell),
      matchesGoldenFile('goldens/home_desktop.png'),
    );
  });

  testWidgets('Телефон: визуальный снимок главного экрана', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = AppController(
      engine: _FakeEngine(),
      store: _MemoryStore(),
      cookies: CookieStore(),
    );
    await tester.pumpWidget(AppRoot(controller: controller));
    await controller.initialize();
    await tester.pump();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MainShell),
      matchesGoldenFile('goldens/home_mobile.png'),
    );
  });
}
