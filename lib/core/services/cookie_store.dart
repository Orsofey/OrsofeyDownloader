import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dpapi_cookie_file.dart';

class CookieStore {
  static const _channel = MethodChannel('com.orsofey.downloader/actions');
  final DpapiCookieFile? _windows = Platform.isWindows
      ? DpapiCookieFile()
      : null;

  Future<void> save(String content) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('saveCookies', {'content': content});
      return;
    }
    if (Platform.isWindows) {
      await _windows!.save(content);
      return;
    }
    throw UnsupportedError('Хранение cookies не поддерживается');
  }

  Future<String?> _read() async {
    if (Platform.isAndroid) {
      return _channel.invokeMethod<String>('readCookies');
    }
    if (Platform.isWindows) return _windows!.read();
    return null;
  }

  Future<void> clear() async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('clearCookies');
      return;
    }
    if (Platform.isWindows) await _windows!.clear();
  }

  Future<File?> materialize(String taskId) async {
    final content = await _read();
    if (content == null || content.trim().isEmpty) return null;
    final directory = await getTemporaryDirectory();
    final safeId = taskId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File(p.join(directory.path, 'orsofey_cookies_$safeId.txt'));
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<void> removeTemporary(File? file) async {
    try {
      if (file != null && await file.exists()) await file.delete();
    } on FileSystemException {
      // A temporary file may already be locked or removed by the OS.
    }
  }
}
