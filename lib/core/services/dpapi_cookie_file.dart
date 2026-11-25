import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _ProtectNative = Int32 Function(
  Pointer<_DataBlob>,
  Pointer<Utf16>,
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<Void>,
  Uint32,
  Pointer<_DataBlob>,
);
typedef _ProtectDart = int Function(
  Pointer<_DataBlob>,
  Pointer<Utf16>,
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<Void>,
  int,
  Pointer<_DataBlob>,
);
typedef _UnprotectNative = Int32 Function(
  Pointer<_DataBlob>,
  Pointer<Pointer<Utf16>>,
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<Void>,
  Uint32,
  Pointer<_DataBlob>,
);
typedef _UnprotectDart = int Function(
  Pointer<_DataBlob>,
  Pointer<Pointer<Utf16>>,
  Pointer<_DataBlob>,
  Pointer<Void>,
  Pointer<Void>,
  int,
  Pointer<_DataBlob>,
);
typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void>);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void>);

class DpapiCookieFile {
  DpapiCookieFile({this._filePath});

  final String? _filePath;
  final _crypt32 = DynamicLibrary.open('crypt32.dll');
  final _kernel32 = DynamicLibrary.open('kernel32.dll');

  Future<File> _file() async {
    if (_filePath != null) {
      final file = File(_filePath).absolute;
      await file.parent.create(recursive: true);
      return file;
    }
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File(p.join(directory.path, 'cookies.dpapi'));
  }

  Future<void> save(String content) async {
    final encrypted = _protect(utf8.encode(content));
    final file = await _file();
    await file.writeAsString(base64Encode(encrypted), flush: true);
  }

  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final encoded = (await file.readAsString()).trim();
    if (encoded.isEmpty) return null;
    final decrypted = _unprotect(base64Decode(encoded));
    return utf8.decode(decrypted);
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  List<int> _protect(List<int> value) {
    final protect = _crypt32.lookupFunction<_ProtectNative, _ProtectDart>(
      'CryptProtectData',
    );
    final input = calloc<_DataBlob>();
    final output = calloc<_DataBlob>();
    final bytes = calloc<Uint8>(value.length);
    try {
      bytes.asTypedList(value.length).setAll(0, value);
      input.ref.cbData = value.length;
      input.ref.pbData = bytes;
      final result = protect(
        input,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        1, // CRYPTPROTECT_UI_FORBIDDEN
        output,
      );
      if (result == 0) {
        throw StateError('CryptProtectData failed');
      }
      return Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
    } finally {
      if (output.ref.pbData != nullptr) _localFree(output.ref.pbData);
      calloc.free(bytes);
      calloc.free(input);
      calloc.free(output);
    }
  }

  List<int> _unprotect(List<int> value) {
    final unprotect = _crypt32.lookupFunction<_UnprotectNative, _UnprotectDart>(
      'CryptUnprotectData',
    );
    final input = calloc<_DataBlob>();
    final output = calloc<_DataBlob>();
    final bytes = calloc<Uint8>(value.length);
    try {
      bytes.asTypedList(value.length).setAll(0, value);
      input.ref.cbData = value.length;
      input.ref.pbData = bytes;
      final result = unprotect(
        input,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        1,
        output,
      );
      if (result == 0) {
        throw StateError('CryptUnprotectData failed');
      }
      return Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
    } finally {
      if (output.ref.pbData != nullptr) _localFree(output.ref.pbData);
      calloc.free(bytes);
      calloc.free(input);
      calloc.free(output);
    }
  }

  void _localFree(Pointer<Uint8> pointer) {
    final localFree = _kernel32
        .lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');
    localFree(pointer.cast());
  }
}
