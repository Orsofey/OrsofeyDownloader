import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/app_controller.dart';
import 'core/services/cookie_store.dart';
import 'core/services/download_engine.dart';
import 'core/services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    engine: createDownloadEngine(),
    store: LocalStore(),
    cookies: CookieStore(),
  );
  runApp(AppRoot(controller: controller));
  await controller.initialize();
}
