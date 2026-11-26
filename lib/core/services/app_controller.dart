import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/download_task.dart';
import '../models/media_info.dart';
import '../utils/url_parser.dart';
import 'cookie_store.dart';
import 'download_engine.dart';
import 'local_store.dart';
import 'native_actions.dart';

class AppController extends ChangeNotifier {
  factory AppController({
    required DownloadEngine engine,
    required LocalStore store,
    required CookieStore cookies,
  }) {
    return AppController._(engine, store, cookies);
  }

  AppController._(this._engine, this._store, this._cookies);

  final DownloadEngine _engine;
  final LocalStore _store;
  final CookieStore _cookies;

  AppSettings settings = const AppSettings();
  List<DownloadTask> tasks = [];
  EngineStatus? engineStatus;
  MediaInfo? preview;
  Set<int> selectedPlaylistEntries = {};
  bool loaded = false;
  bool analyzing = false;
  bool updatingEngine = false;
  String? inspectError;
  String? actionMessage;
  int navigationRequest = 0;

  int _activeCount = 0;
  int _taskCounter = 0;

  bool get hasPreview => preview != null;
  List<DownloadTask> get activeTasks =>
      tasks.where((task) => task.status.isActive).toList();
  List<DownloadTask> get historyTasks =>
      tasks.where((task) => task.status.isFinished).toList()..sort(
        (a, b) => (b.completedAt ?? b.createdAt).compareTo(
          a.completedAt ?? a.createdAt,
        ),
      );
  int get completedToday {
    final now = DateTime.now();
    return tasks
        .where(
          (task) =>
              task.status == DownloadStatus.completed &&
              task.completedAt != null &&
              task.completedAt!.year == now.year &&
              task.completedAt!.month == now.month &&
              task.completedAt!.day == now.day,
        )
        .length;
  }

  Future<void> initialize() async {
    final state = await _store.load();
    settings = state.settings;
    tasks = state.tasks.map((task) {
      if (task.status.isActive) {
        return task.copyWith(status: DownloadStatus.paused, progress: 0);
      }
      return task;
    }).toList();

    if (settings.downloadDirectory.isEmpty) {
      try {
        settings = settings.copyWith(
          downloadDirectory: await _engine.getDefaultDownloadDirectory(),
        );
      } on Object {
        settings = settings.copyWith(downloadDirectory: '');
      }
    }
    loaded = true;
    notifyListeners();
    await refreshEngineStatus();
    await _save();
  }

  Future<void> refreshEngineStatus() async {
    engineStatus = await _engine.getStatus();
    notifyListeners();
  }

  Future<void> analyze(String link) async {
    final parsed = parseSupportedLink(link);
    if (parsed == null) {
      inspectError = 'Поддерживаются ссылки YouTube, TikTok и VK Видео.';
      preview = null;
      notifyListeners();
      return;
    }
    analyzing = true;
    inspectError = null;
    preview = null;
    notifyListeners();
    File? cookiesFile;
    try {
      cookiesFile = settings.hasCookies
          ? await _cookies.materialize('inspect')
          : null;
      final browser = !settings.hasCookies && settings.cookiesBrowser.isNotEmpty
          ? settings.cookiesBrowser
          : null;
      preview = await _engine.inspect(
        parsed.uri.toString(),
        cookiesFile: cookiesFile?.path,
        cookiesFromBrowser: browser,
      );
      selectedPlaylistEntries = preview!.entries
          .map((entry) => entry.index)
          .toSet();
    } on DownloadException catch (error) {
      preview = null;
      inspectError = error.message;
    } on Object catch (error) {
      preview = null;
      inspectError = 'Не удалось получить данные видео: $error';
    } finally {
      await _cookies.removeTemporary(cookiesFile);
      analyzing = false;
      notifyListeners();
    }
  }

  void clearPreview() {
    preview = null;
    inspectError = null;
    selectedPlaylistEntries = {};
    notifyListeners();
  }

  void togglePlaylistEntry(int index) {
    final next = Set<int>.from(selectedPlaylistEntries);
    if (!next.remove(index)) next.add(index);
    selectedPlaylistEntries = next;
    notifyListeners();
  }

  void selectAllPlaylistEntries(bool selected) {
    selectedPlaylistEntries = selected
        ? preview?.entries.map((entry) => entry.index).toSet() ?? {}
        : {};
    notifyListeners();
  }

  Future<List<DownloadTask>> enqueue({
    required DownloadKind kind,
    required int quality,
    required String container,
    required int audioBitrate,
    required ThumbnailMode thumbnailMode,
    required bool writeSubtitles,
    required bool autoSubtitles,
    required bool embedSubtitles,
    required String subtitleLanguages,
  }) async {
    final info = preview;
    if (info == null) return const [];
    if (info.isPlaylist && selectedPlaylistEntries.isEmpty) {
      actionMessage = 'Выберите хотя бы одно видео из плейлиста.';
      notifyListeners();
      return const [];
    }

    await _resolvedDirectory();
    final now = DateTime.now();
    final created = <DownloadTask>[];

    if (info.isPlaylist) {
      final selected = info.entries
          .where((entry) => selectedPlaylistEntries.contains(entry.index))
          .toList();
      for (final entry in selected) {
        created.add(
          DownloadTask(
            id: _newTaskId(),
            url: entry.url,
            title: entry.title,
            source: info.source,
            kind: kind,
            quality: quality,
            container: container,
            audioBitrate: audioBitrate,
            createdAt: now,
            thumbnailUrl: entry.thumbnailUrl,
            uploader: info.uploader,
            duration: entry.duration,
            thumbnailMode: thumbnailMode,
            writeSubtitles: writeSubtitles,
            autoSubtitles: autoSubtitles,
            embedSubtitles: embedSubtitles,
            subtitleLanguages: subtitleLanguages,
            playlistTitle: info.title,
            playlistItems: [entry.index],
          ),
        );
      }
    } else {
      created.add(
        DownloadTask(
          id: _newTaskId(),
          url: info.webpageUrl,
          title: info.title,
          source: info.source,
          kind: kind,
          quality: quality,
          container: container,
          audioBitrate: audioBitrate,
          createdAt: now,
          thumbnailUrl: info.thumbnailUrl,
          uploader: info.uploader,
          duration: info.duration,
          thumbnailMode: thumbnailMode,
          writeSubtitles: writeSubtitles,
          autoSubtitles: autoSubtitles,
          embedSubtitles: embedSubtitles,
          subtitleLanguages: subtitleLanguages,
        ),
      );
    }

    tasks = [...created.reversed, ...tasks];
    actionMessage = created.length == 1
        ? 'Добавлено в очередь'
        : 'Добавлено в очередь: ${created.length}';
    notifyListeners();
    await _save();
    _pump();
    clearPreview();
    return created;
  }

  Future<void> pause(String taskId) async {
    final task = _task(taskId);
    if (task == null) return;
    if (task.status == DownloadStatus.downloading) {
      await _engine.stop(taskId);
    }
    _replace(
      task.copyWith(status: DownloadStatus.paused, clearNetworkStats: true),
    );
    notifyListeners();
    await _save();
    _pump();
  }

  Future<void> resume(String taskId) async {
    final task = _task(taskId);
    if (task == null || task.status.isActive) return;
    _replace(
      task.copyWith(
        status: DownloadStatus.queued,
        clearError: true,
        clearCompletedAt: true,
      ),
    );
    notifyListeners();
    await _save();
    _pump();
  }

  Future<void> retry(String taskId) async {
    final task = _task(taskId);
    if (task == null) return;
    if (task.status.isActive) return;
    _replace(
      task.copyWith(
        status: DownloadStatus.queued,
        clearError: true,
        clearCompletedAt: true,
        progress: task.progress < 1 ? task.progress : 0,
      ),
    );
    notifyListeners();
    await _save();
    _pump();
  }

  Future<void> cancel(String taskId) async {
    final task = _task(taskId);
    if (task == null) return;
    if (task.status == DownloadStatus.downloading) {
      await _engine.stop(taskId);
    }
    _replace(
      task.copyWith(
        status: DownloadStatus.canceled,
        clearNetworkStats: true,
        completedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _save();
    _pump();
  }

  Future<void> removeTask(String taskId) async {
    final task = _task(taskId);
    if (task?.status.isActive ?? false) await _engine.stop(taskId);
    tasks.removeWhere((item) => item.id == taskId);
    notifyListeners();
    await _save();
  }

  Future<void> clearFinished() async {
    tasks.removeWhere((task) => task.status.isFinished);
    notifyListeners();
    await _save();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    if (settings.downloadDirectory.isNotEmpty &&
        !settings.downloadDirectory.startsWith('content://')) {
      await Directory(settings.downloadDirectory).create(recursive: true);
    }
    notifyListeners();
    await _save();
    _pump();
  }

  Future<String?> chooseDownloadDirectory() async {
    try {
      final result = await FilePickerHelper.pickDirectory(
        settings.downloadDirectory,
      );
      if (result == null || result.isEmpty) return null;
      await updateSettings(settings.copyWith(downloadDirectory: result));
      return result;
    } on Object catch (error) {
      actionMessage = 'Не удалось выбрать папку: $error';
      notifyListeners();
      return null;
    }
  }

  Future<bool> importCookiesFile() async {
    try {
      final content = await FilePickerHelper.pickCookiesContent();
      if (content == null) return false;
      if (content.trim().isEmpty) {
        actionMessage = 'Файл cookies пустой.';
        notifyListeners();
        return false;
      }
      await _cookies.save(content);
      settings = settings.copyWith(hasCookies: true, cookiesBrowser: '');
      actionMessage = 'Cookies сохранены в зашифрованном хранилище.';
      notifyListeners();
      await _save();
      return true;
    } on Object catch (error) {
      actionMessage = 'Не удалось прочитать cookies: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> clearCookies() async {
    await _cookies.clear();
    settings = settings.copyWith(hasCookies: false);
    actionMessage = 'Cookies удалены.';
    notifyListeners();
    await _save();
  }

  Future<void> updateEngine() async {
    if (updatingEngine) return;
    updatingEngine = true;
    actionMessage = null;
    notifyListeners();
    try {
      await _engine.updateEngine();
      actionMessage = 'Компоненты загрузчика обновлены.';
    } on DownloadException catch (error) {
      actionMessage = error.message;
    } finally {
      updatingEngine = false;
      await refreshEngineStatus();
    }
  }

  Future<void> openFile(String path) async {
    try {
      await NativeActions.openFile(path);
    } on Object catch (error) {
      actionMessage = 'Не удалось открыть файл: $error';
      notifyListeners();
    }
  }

  Future<void> openTaskFolder(DownloadTask task) async {
    try {
      await NativeActions.openFolder(
        Platform.isAndroid
            ? settings.downloadDirectory
            : task.filePath ?? settings.downloadDirectory,
        selectFile: task.filePath,
      );
    } on Object catch (error) {
      actionMessage = 'Не удалось открыть папку: $error';
      notifyListeners();
    }
  }

  void openQueue() {
    navigationRequest++;
    notifyListeners();
  }

  void consumeActionMessage() {
    actionMessage = null;
    notifyListeners();
  }

  void _pump() {
    while (_activeCount < settings.maxConcurrent) {
      final next = tasks
          .where((task) => task.status == DownloadStatus.queued)
          .firstOrNull;
      if (next == null) return;
      unawaited(_runTask(next));
    }
  }

  Future<void> _runTask(DownloadTask task) async {
    _activeCount++;
    _replace(
      task.copyWith(status: DownloadStatus.downloading, clearError: true),
    );
    notifyListeners();

    File? cookiesFile;
    try {
      cookiesFile = settings.hasCookies
          ? await _cookies.materialize(task.id)
          : null;
      final browser = settings.hasCookies || Platform.isAndroid
          ? null
          : settings.cookiesBrowser.isNotEmpty
          ? settings.cookiesBrowser
          : null;
      final job = DownloadJob(
        taskId: task.id,
        url: task.url,
        directory: await _resolvedDirectory(),
        kind: task.kind,
        quality: task.quality,
        container: task.container,
        audioBitrate: task.audioBitrate,
        thumbnailMode: task.thumbnailMode,
        writeSubtitles: task.writeSubtitles,
        autoSubtitles: task.autoSubtitles,
        embedSubtitles: task.embedSubtitles,
        subtitleLanguages: task.subtitleLanguages,
        cookiesFile: cookiesFile?.path,
        cookiesFromBrowser: browser,
        playlistItems: task.playlistItems,
      );

      final filePath = await _engine.download(
        job,
        onProgress: (progress) {
          final current = _task(task.id);
          if (current == null || !current.status.isActive) return;
          _replace(
            current.copyWith(
              status: progress.stage ?? DownloadStatus.downloading,
              progress:
                  progress.fraction ??
                  (progress.totalBytes != null &&
                          progress.downloadedBytes != null
                      ? progress.downloadedBytes! / progress.totalBytes!
                      : current.progress),
              speed: progress.speed,
              etaSeconds: progress.etaSeconds,
              downloadedBytes: progress.downloadedBytes,
              totalBytes: progress.totalBytes,
              clearNetworkStats: progress.stage == DownloadStatus.processing,
            ),
          );
          notifyListeners();
        },
      );
      final current = _task(task.id);
      if (current == null) return;
      _replace(
        current.copyWith(
          status: DownloadStatus.completed,
          progress: 1,
          filePath: filePath.isNotEmpty ? filePath : current.filePath,
          completedAt: DateTime.now(),
          clearNetworkStats: true,
          clearError: true,
        ),
      );
    } on DownloadStoppedException {
      final current = _task(task.id);
      if (current == null) return;
      if (current.status == DownloadStatus.downloading ||
          current.status == DownloadStatus.processing) {
        _replace(
          current.copyWith(
            status: DownloadStatus.paused,
            clearNetworkStats: true,
          ),
        );
      }
    } on DownloadException catch (error) {
      final current = _task(task.id);
      if (current == null) return;
      _replace(
        current.copyWith(
          status: DownloadStatus.failed,
          error: error.message,
          completedAt: DateTime.now(),
          clearNetworkStats: true,
        ),
      );
    } on Object catch (error) {
      final current = _task(task.id);
      if (current == null) return;
      _replace(
        current.copyWith(
          status: DownloadStatus.failed,
          error: 'Неожиданная ошибка: $error',
          completedAt: DateTime.now(),
          clearNetworkStats: true,
        ),
      );
    } finally {
      await _cookies.removeTemporary(cookiesFile);
      cookiesFile = null;
      _activeCount--;
      notifyListeners();
      await _save();
      _pump();
    }
  }

  Future<String> _resolvedDirectory() async {
    if (settings.downloadDirectory.isNotEmpty) {
      return settings.downloadDirectory;
    }
    final resolved = await _engine.getDefaultDownloadDirectory();
    settings = settings.copyWith(downloadDirectory: resolved);
    await Directory(resolved).create(recursive: true);
    await _save();
    return resolved;
  }

  DownloadTask? _task(String id) {
    return tasks.where((item) => item.id == id).firstOrNull;
  }

  void _replace(DownloadTask task) {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index == -1) return;
    tasks[index] = task;
  }

  String _newTaskId() {
    _taskCounter++;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'task_${timestamp}_$_taskCounter';
  }

  Future<void> _save() async {
    await _store.save(settings, tasks);
  }

  @override
  void dispose() {
    for (final task in tasks.where((item) => item.status.isActive).toList()) {
      unawaited(_engine.stop(task.id));
    }
    super.dispose();
  }
}

class FilePickerHelper {
  static Future<String?> pickDirectory(String initial) async {
    final result = await FilePicker.pickDirectory(
      initialDirectory: initial.isEmpty ? null : initial,
    );
    if (result == null) return null;
    if (result.scheme == 'file') return result.toFilePath();
    return result.toString();
  }

  static Future<String?> pickCookiesContent() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null) return null;
    final bytes = await result.readAsBytes();
    return utf8.decode(bytes);
  }
}
