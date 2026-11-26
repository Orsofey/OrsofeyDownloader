import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orsofey_downloader/core/models/download_task.dart';
import 'package:orsofey_downloader/core/models/media_info.dart';
import 'package:orsofey_downloader/core/services/yt_dlp_engine.dart';

void main() {
  test('Windows: реальные метаданные и короткая загрузка VK', () async {
    const url = 'https://vk.com/video205387401_165548505';
    final engine = YtDlpEngine();
    final status = await engine.getStatus();
    expect(status.available, isTrue, reason: status.description);

    final info = await engine.inspect(url);
    expect(info.id, '205387401_165548505');
    expect(info.formats, isNotEmpty);

    final directory = Directory(
      'build/smoke-${DateTime.now().millisecondsSinceEpoch}',
    ).absolute;
    var sawProgress = false;
    final output = await engine.download(
      DownloadJob(
        taskId: 'smoke_${DateTime.now().millisecondsSinceEpoch}',
        url: url,
        directory: directory.path,
        kind: DownloadKind.video,
        quality: 360,
        container: 'mp4',
        audioBitrate: 192,
        thumbnailMode: ThumbnailMode.none,
        writeSubtitles: false,
        autoSubtitles: false,
        embedSubtitles: false,
        subtitleLanguages: 'ru,en',
      ),
      onProgress: (progress) {
        if (progress.fraction != null) {
          sawProgress = true;
          expect(progress.fraction!, inInclusiveRange(0, 1));
        }
      },
    );
    expect(output, isNotEmpty);
    expect(sawProgress, isTrue);
    expect(await File(output).exists(), isTrue);
    expect(await File(output).length(), greaterThan(1000));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'Windows: YouTube использует рабочую альтернативную аудиодорожку',
    () async {
      const url = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
      final engine = YtDlpEngine();
      final status = await engine.getStatus();
      expect(status.available, isTrue, reason: status.description);

      final info = await engine.inspect(url);
      expect(info.id, 'jNQXAC9IVRw');
      expect(info.formats, isNotEmpty);

      final directory = Directory(
        'build/youtube-smoke-${DateTime.now().millisecondsSinceEpoch}',
      ).absolute;
      var sawProgress = false;
      final output = await engine.download(
        DownloadJob(
          taskId: 'youtube_${DateTime.now().millisecondsSinceEpoch}',
          url: url,
          directory: directory.path,
          kind: DownloadKind.video,
          quality: 720,
          container: 'mp4',
          audioBitrate: 192,
          thumbnailMode: ThumbnailMode.none,
          writeSubtitles: false,
          autoSubtitles: false,
          embedSubtitles: false,
          subtitleLanguages: 'ru,en',
        ),
        onProgress: (progress) {
          if (progress.fraction != null) {
            sawProgress = true;
            expect(progress.fraction!, inInclusiveRange(0, 1));
          }
        },
      );
      expect(output, isNotEmpty);
      expect(sawProgress, isTrue);
      expect(await File(output).exists(), isTrue);
      expect(await File(output).length(), greaterThan(1000));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
