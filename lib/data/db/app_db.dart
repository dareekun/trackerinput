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
    final path = p.join(dbPath, 'auth_demo.db'); 
    
    return await openDatabase(
      path,
      // Versi dinaikkan ke 2 untuk memicu pembuatan tabel baru pada DB yang sudah ada
      version: 2, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Dijalankan jika database belum pernah ada sebelumnya
  Future _onCreate(Database db, int version) async {
    // Tabel Users
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

    // Tabel Items
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

    // Tabel Transactions (Menyelesaikan error "no such table")
    await _createTransactionsTable(db);
  }

  // Dijalankan jika database sudah ada tapi versinya lebih rendah (Migrasi)
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Jika user update dari versi 1 ke 2, buat tabel transaksi yang belum ada
      await _createTransactionsTable(db);
    }
  }

  // Helper untuk membuat tabel transaksi agar kode tetap rapi
  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER,
        item_code TEXT,
        value REAL,
        date TEXT,
        created_at TEXT,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');
  }

  /* -------------------------- CRUD ITEMS -------------------------- */

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

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateItem(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'items',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertItem(Map<String, dynamic> data) async {
    final db = await database;
    if (!data.containsKey('created_at')) {
      data['created_at'] = DateTime.now().toIso8601String();
    }
    return await db.insert('items', data);
  }

  Future<List<Map<String, dynamic>>> getAllItems() async {
    final db = await database;
    return await db.query('items', orderBy: 'id DESC');
  }

  /* ----------------------- CRUD TRANSACTIONS ----------------------- */

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('transactions', row);
  }

  // --- FUNGSI AMBIL SEMUA TRANSAKSI DENGAN JOIN ---
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    // Kita melakukan JOIN agar mendapatkan kolom description dari tabel items
    return await db.rawQuery('''
      SELECT t.*, i.description 
      FROM transactions t
      LEFT JOIN items i ON t.item_id = i.id
      ORDER BY t.date DESC, t.id DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getTransactionsByItem(int itemId) async {
    final db = await database;
    return await db.query(
      'transactions', 
      where: 'item_id = ?', 
      whereArgs: [itemId], 
      orderBy: 'date DESC'
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}