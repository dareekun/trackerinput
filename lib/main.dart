import 'dart:io'; // Untuk mengecek platform
import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'data/db/factory_stub.dart'
  if (dart.library.html) 'data/db/factory_web.dart'
  if (dart.library.ffi)  'data/db/factory_desktop.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // *** PENTING: Inisialisasi factory sebelum ada kode yang menyentuh DB ***
  await initDbFactory();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720), // Ukuran default saat dibuka
      center: true,          // Menaruh jendela di tengah layar
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      minimumSize: Size(800, 720), // Ukuran minimal yang diperbolehkan
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B77E8), brightness: Brightness.light),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Input Tracker',
      theme: theme,
      routerConfig: AppRouter.router,
    );
  }
}



