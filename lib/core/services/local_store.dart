import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/download_task.dart';

class LocalState {
  const LocalState({required this.settings, required this.tasks});

  final AppSettings settings;
  final List<DownloadTask> tasks;
}

class LocalStore {
  Future<File> _stateFile() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File(p.join(directory.path, 'state.json'));
  }

  Future<LocalState> load() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) {
        return const LocalState(settings: AppSettings(), tasks: []);
      }
      final content = await file.readAsString();
      final json = Map<String, dynamic>.from(jsonDecode(content) as Map);
      final tasks = (json['tasks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => DownloadTask.fromJson(Map<String, dynamic>.from(item)))
          .where((task) => task.id.isNotEmpty)
          .toList();
      return LocalState(
        settings: AppSettings.fromJson(
          Map<String, dynamic>.from(json['settings'] as Map? ?? const {}),
        ),
        tasks: tasks,
      );
    } on Object {
      return const LocalState(settings: AppSettings(), tasks: []);
    }
  }

  Future<void> save(AppSettings settings, List<DownloadTask> tasks) async {
    final file = await _stateFile();
    final temporary = File('${file.path}.tmp');
    final content = jsonEncode({
      'version': 1,
      'settings': settings.toJson(),
      'tasks': tasks.take(600).map((task) => task.toJson()).toList(),
    });
    await temporary.writeAsString(content, flush: true);
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      await file.writeAsString(content, flush: true);
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
