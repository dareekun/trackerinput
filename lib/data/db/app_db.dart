import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDb {
  AppDb._internal();
  static final AppDb instance = AppDb._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    // Anda bisa tetap menggunakan nama 'auth_demo.db' atau menggantinya ke nama yang lebih umum
    final path = p.join(dbPath, 'auth_demo.db'); 
    
    return await openDatabase(
      path,
      version: 1, // Jika Anda sudah pernah menjalankan app, naikkan versi ke 2 dan gunakan onUpgrade
      onCreate: (db, version) async {
        // Tabel Users (Eksis)
        await db.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            recovery_question TEXT,
            recovery_answer_hash TEXT,
            recovery_salt TEXT,
            created_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_users_email ON users(email)');

        // Tabel Items (Baru)
        await db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT NOT NULL,
            description TEXT,
            limit_value REAL,
            is_reminder INTEGER,
            reminder_limit REAL,
            created_at TEXT
          )
        ''');
      },
    );
  }

  /* -------------------------- CRUD ITEMS -------------------------- */

  /// Fungsi untuk mengecek keberadaan Item Code
  Future<bool> isItemCodeExists(String code) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'items',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Fungsi untuk Menghapus keberadaan Item Code
  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Fungsi insert yang sudah ada (pastikan tetap seperti ini)
  Future<int> insertItem(Map<String, dynamic> data) async {
    final db = await database;
    if (!data.containsKey('created_at')) {
      data['created_at'] = DateTime.now().toIso8601String();
    }
    return await db.insert('items', data);
  }

  /// Fungsi tambahan: mengambil semua data item (untuk list nantinya)
  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    return await db.query('items', orderBy: 'id DESC');
  }
}