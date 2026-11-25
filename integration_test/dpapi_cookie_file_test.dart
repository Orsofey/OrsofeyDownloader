import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orsofey_downloader/core/services/dpapi_cookie_file.dart';

void main() {
  test('DPAPI шифрует и восстанавливает тестовые данные', () async {
    final file = File('build/dpapi-test/cookies.bin').absolute;
    final store = DpapiCookieFile(filePath: file.path);
    const value =
        '# Netscape test cookie\nexample.com\tFALSE\t/\tFALSE\t0\ttest\tvalue';

    await store.save(value);
    final encrypted = await file.readAsString();
    expect(encrypted, isNot(contains('example.com')));
    expect(await store.read(), value);

    await store.clear();
    expect(await file.exists(), isFalse);
  });
}
