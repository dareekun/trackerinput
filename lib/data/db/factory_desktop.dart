import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initDbFactory() async {
  sqfliteFfiInit();                    // inisialisasi runtime SQLite FFI
  databaseFactory = databaseFactoryFfi; // set factory global untuk API sqflite
}
