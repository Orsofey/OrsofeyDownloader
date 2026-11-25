import 'dart:io';

import 'package:flutter/services.dart';

class NativeActions {
  static const _channel = MethodChannel('com.orsofey.downloader/actions');

  static Future<void> openFile(String path) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openFile', {'path': path});
      return;
    }
    if (Platform.isWindows) {
      await Process.run('rundll32.exe', ['url.dll,FileProtocolHandler', path]);
      return;
    }
    throw UnsupportedError('Открытие файлов не поддерживается');
  }

  static Future<void> openFolder(String path, {String? selectFile}) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('openFolder', {'path': path});
      return;
    }
    if (Platform.isWindows) {
      final argument = selectFile == null || selectFile.isEmpty
          ? path
          : '/select,$selectFile';
      await Process.run('explorer.exe', [argument]);
      return;
    }
    throw UnsupportedError('Открытие папки не поддерживается');
  }
}
