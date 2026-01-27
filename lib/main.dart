import 'dart:io';
import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'data/session/session_manager.dart'; // Import SessionManager

// Factory DB imports
import 'data/db/factory_stub.dart'
  if (dart.library.html) 'data/db/factory_web.dart'
  if (dart.library.ffi)  'data/db/factory_desktop.dart';

// 1. GlobalKey untuk Navigator (Sangat krusial untuk Auto Logout)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi DB Factory
  await initDbFactory();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Pengaturan Jendela Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 770),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      minimumSize: Size(1280, 770),
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 2. Cek Sesi: Jika user sudah login, nyalakan timer auto-logout
  final currentUser = await SessionManager.getCurrentUser();
  if (currentUser != null) {
    SessionManager.startTimeoutTimer();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B77E8), 
        brightness: Brightness.light
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder()
      ),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Input Tracker',
      theme: theme,
      // 3. Gunakan router yang sudah dikonfigurasi dengan navigatorKey
      routerConfig: AppRouter.router,
    );
  }
}