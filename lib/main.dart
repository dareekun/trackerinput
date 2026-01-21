
import 'package:flutter/material.dart';
import 'router/app_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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



