
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:sqflite/sqflite.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // WEB: pakai adapter web (IndexedDB)
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    try {
      sqfliteFfiInit(); 
      if (!await _isMobile()) {
        databaseFactory = databaseFactoryFfi;
      }
    } catch (_) {
      
    }
  }

  runApp(const MyApp());
}

Future<bool> _isMobile() async {
  return false;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth SQLite Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const LoginPage(),
    );
  }
}
