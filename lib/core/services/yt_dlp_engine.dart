import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/download_task.dart';
import '../models/media_info.dart';
import '../utils/url_parser.dart';
import 'android_download_engine.dart' show friendlyEngineError;
import 'download_engine.dart';

class YtDlpEngine implements DownloadEngine {
  final Map<String, Process> _processes = {};
  final Set<String> _stopping = {};

  String get _engineDirectory {
    final executable = File(Platform.resolvedExecutable);
    return p.join(executable.parent.path, 'engine');
  }

  String get _ytDlpPath {
    final bundled = p.join(_engineDirectory, 'yt-dlp.exe');
    if (File(bundled).existsSync()) return bundled;
    final override = Platform.environment['ORSOFEY_YT_DLP'];
    if (override != null && override.isNotEmpty) return override;
    return 'yt-dlp';
  }

  String? get _ffmpegLocation {
    final bundled = p.join(_engineDirectory, 'ffmpeg.exe');
    if (File(bundled).existsSync()) return _engineDirectory;
    final override = Platform.environment['ORSOFEY_FFMPEG_DIR'];
    if (override != null && override.isNotEmpty) return override;
    return null;
  }

  Future<List<String>> _runtimeArguments() async {
    final bundledDeno = p.join(_engineDirectory, 'deno.exe');
    if (await File(bundledDeno).exists()) {
      return ['--js-runtimes', 'deno:$bundledDeno'];
    }
    final denoOverride = Platform.environment['ORSOFEY_DENO'];
    if (denoOverride != null && denoOverride.isNotEmpty) {
      return ['--js-runtimes', 'deno:$denoOverride'];
    }
    final deno = await _findExecutable('deno.exe');
    if (deno != null) return ['--js-runtimes', 'deno:$deno'];
    final node = await _findExecutable('node.exe');
    if (node != null) return ['--js-runtimes', 'node:$node'];
    return const [];
  }

  Future<String?> _findExecutable(String name) async {
    try {
      final result = await Process.run('where.exe', [name]);
      if (result.exitCode == 0) {
        final lines = const LineSplitter().convert(result.stdout.toString());
        if (lines.isNotEmpty) return lines.first.trim();
      }
    } on ProcessException {
      // The engine reports a useful error if no runtime is available.
    }
    return null;
  }

  Future<List<String>> _baseArguments() async {
    final arguments = <String>[
      '--ignore-config',
      '--no-config-locations',
      '--no-update',
      '--no-warnings',
      '--socket-timeout',
      '30',
      '--retries',
      '3',
      '--extractor-retries',
      '3',
    ];
    arguments.addAll(await _runtimeArguments());
    final ffmpeg = _ffmpegLocation;
    if (ffmpeg != null) {
      arguments.addAll(['--ffmpeg-location', ffmpeg]);
    }
    return arguments;
  }

  @override
  Future<EngineStatus> getStatus() async {
    try {
      final result = await Process.run(
        _ytDlpPath,
        ['--version'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        return EngineStatus(
          available: false,
          version: '—',
          description: result.stderr.toString().trim(),
        );
      }
      final runtime = await _runtimeArguments();
      return EngineStatus(
        available: true,
        version: result.stdout.toString().trim(),
        description: runtime.isEmpty
            ? 'yt-dlp · FFmpeg · JS-runtime не найден'
            : 'yt-dlp · FFmpeg · ${runtime[1].startsWith('deno:') ? 'Deno' : 'Node.js'}',
      );
    } on ProcessException catch (error) {
      return EngineStatus(
        available: false,
        version: '—',
        description: 'yt-dlp не найден: ${error.message}',
      );
    }
  }

  @override
  Future<String> getDefaultDownloadDirectory() async {
    final downloads = await getDownloadsDirectory();
    final base =
        downloads?.path ??
        p.join(Platform.environment['USERPROFILE'] ?? '', 'Downloads');
    return p.join(base, 'Orsofey Downloader');
  }

  @override
  Future<MediaInfo> inspect(
    String url, {
    String? cookiesFile,
    String? cookiesFromBrowser,
  }) async {
    final arguments = await _baseArguments();
    arguments.addAll([
      '--dump-single-json',
      '--flat-playlist',
      '--skip-download',
    ]);
    _addCookies(arguments, cookiesFile, cookiesFromBrowser);
    arguments.add(url);

    try {
      final result = await Process.run(
        _ytDlpPath,
        arguments,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: false,
      );
      if (result.exitCode != 0) {
        final details = result.stderr.toString().trim();
        throw DownloadException(friendlyEngineError(details), details);
      }
      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        throw const DownloadException('Площадка вернула пустой ответ');
      }
      final map = Map<String, dynamic>.from(jsonDecode(output) as Map);
      final parsed = parseSupportedLink(url);
      return MediaInfo.fromYtDlpJson(
        map,
        parsed?.source ?? MediaSource.unknown,
      );
    } on ProcessException catch (error) {
      throw DownloadException(
        'Локальный движок не найден. Переустановите приложение или обновите компоненты.',
        error.message,
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
    final directory = Directory(job.directory);
    if (!await directory.exists()) await directory.create(recursive: true);

    final arguments = await _baseArguments();
    arguments.addAll([
      '--newline',
      '--continue',
      '--windows-filenames',
      '--trim-filenames',
      '220',
      '--output',
      p.join(directory.path, '%(title).160B [%(id)s].%(ext)s'),
      '--progress-template',
      'download:ORSOFEY|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s',
      '--print',
      'after_move:ORSOFEY_FILE|%(filepath)s',
    ]);

    if (job.playlistItems != null && job.playlistItems!.isNotEmpty) {
      arguments.addAll(['--playlist-items', job.playlistItems!.join(',')]);
    }

    if (job.kind == DownloadKind.audio) {
      arguments.addAll([
        '--extract-audio',
        '--audio-format',
        'mp3',
        '--audio-quality',
        '${job.audioBitrate}K',
      ]);
    } else {
      arguments.addAll([
        '--format',
        _formatSelector(job.quality, job.container),
        '--merge-output-format',
        job.container,
      ]);
    }

    if (job.writeSubtitles || job.embedSubtitles) {
      arguments.add('--write-subs');
    }
    if (job.autoSubtitles) arguments.add('--write-auto-subs');
    if ((job.writeSubtitles || job.embedSubtitles) &&
        job.subtitleLanguages.trim().isNotEmpty) {
      arguments.addAll(['--sub-langs', job.subtitleLanguages.trim()]);
      arguments.addAll(['--sub-format', 'best/srt/vtt']);
    }
    if (job.embedSubtitles) arguments.add('--embed-subs');

    switch (job.thumbnailMode) {
      case ThumbnailMode.none:
        break;
      case ThumbnailMode.separate:
        arguments.add('--write-thumbnail');
      case ThumbnailMode.embed:
        arguments.add('--embed-thumbnail');
    }

    _addCookies(arguments, job.cookiesFile, job.cookiesFromBrowser);
    arguments.add(job.url);

    _stopping.remove(job.taskId);
    late final Process process;
    try {
      process = await Process.start(
        _ytDlpPath,
        arguments,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
    } on ProcessException catch (error) {
      throw DownloadException(
        'Не удалось запустить локальный движок',
        error.message,
      );
    }
    _processes[job.taskId] = process;

    var outputFile = '';
    final errors = <String>[];
    final stdoutDone = _listenLines(process.stdout, (line) {
      if (line.startsWith('ORSOFEY_FILE|')) {
        outputFile = line.substring('ORSOFEY_FILE|'.length).trim();
        return;
      }
      final progress = _parseProgress(line);
      if (progress != null) onProgress(progress);
      if (_isPostProcessing(line)) {
        onProgress(const DownloadProgress(stage: DownloadStatus.processing));
      }
    });
    final stderrDone = _listenLines(process.stderr, (line) {
      errors.add(line);
      if (_isPostProcessing(line)) {
        onProgress(const DownloadProgress(stage: DownloadStatus.processing));
      }
    });

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    _processes.remove(job.taskId);

    if (_stopping.remove(job.taskId) || exitCode == -1) {
      throw const DownloadStoppedException();
    }
    if (exitCode != 0) {
      final details = errors.join('\n').trim();
      throw DownloadException(friendlyEngineError(details), details);
    }
    if (outputFile.isEmpty) {
      throw const DownloadException(
        'Не удалось определить итоговый файл после загрузки',
      );
    }
    return outputFile;
  }

  @override
  Future<void> stop(String taskId) async {
    final process = _processes[taskId];
    if (process == null) return;
    _stopping.add(taskId);
    process.kill();
  }

  @override
  Future<void> updateEngine() async {
    try {
      final result = await Process.run(
        _ytDlpPath,
        ['--update'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        final details = '${result.stdout}\n${result.stderr}'.trim();
        throw DownloadException(friendlyEngineError(details), details);
      }
    } on ProcessException catch (error) {
      throw DownloadException('Не удалось обновить движок', error.message);
    }
  }

  void _addCookies(
    List<String> arguments,
    String? cookiesFile,
    String? cookiesFromBrowser,
  ) {
    if (cookiesFile != null && cookiesFile.isNotEmpty) {
      arguments.addAll(['--cookies', cookiesFile]);
    } else if (cookiesFromBrowser != null && cookiesFromBrowser.isNotEmpty) {
      arguments.addAll(['--cookies-from-browser', cookiesFromBrowser]);
    }
  }

  String _formatSelector(int quality, String container) {
    final extension = container == 'webm' ? 'webm' : 'mp4';
    final audioExtension = extension == 'webm' ? 'webm' : 'm4a';
    final height = quality > 0 ? '[height<=$quality]' : '';
    return 'bestvideo$height[ext=$extension]+bestaudio[ext=$audioExtension]/'
        'best$height[ext=$extension]/'
        'bestvideo$height+bestaudio/best$height';
  }

  DownloadProgress? _parseProgress(String line) {
    if (!line.startsWith('ORSOFEY|')) return null;
    final parts = line.substring('ORSOFEY|'.length).split('|');
    if (parts.length < 5) return null;
    final downloaded = _number(parts[0]);
    final total = _number(parts[1]) ?? _number(parts[2]);
    final speed = _double(parts[3]);
    final eta = _number(parts[4]);
    final fraction = total != null && total > 0 && downloaded != null
        ? (downloaded / total).clamp(0.0, 1.0)
        : null;
    return DownloadProgress(
      fraction: fraction,
      downloadedBytes: downloaded,
      totalBytes: total,
      speed: speed,
      etaSeconds: eta,
      stage: DownloadStatus.downloading,
    );
  }

  int? _number(String value) {
    if (value == 'NA' || value == 'None' || value.isEmpty) return null;
    return double.tryParse(value)?.round();
  }

  double? _double(String value) {
    if (value == 'NA' || value == 'None' || value.isEmpty) return null;
    return double.tryParse(value);
  }

  bool _isPostProcessing(String line) {
    return line.contains('[Merger]') ||
        line.contains('[ExtractAudio]') ||
        line.contains('[VideoConvertor]') ||
        line.contains('[VideoRemuxer]') ||
        line.contains('[FFmpegMetadata]') ||
        line.contains('[EmbedSubtitle]') ||
        line.contains('[ThumbnailsConvertor]');
  }

  Future<void> _listenLines(
    Stream<List<int>> stream,
    void Function(String line) listener,
  ) {
    final completer = Completer<void>();
    late final StreamSubscription<String> subscription;
    subscription = stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          listener,
          onError: completer.complete,
          onDone: () async {
            await subscription.cancel();
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
    return completer.future;
  }
}
