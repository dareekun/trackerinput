import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDb {
  AppDb._internal();
  static final AppDb instance = AppDb._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  /// Mengembalikan path direktori tempat database disimpan
  Future<String> getDbDirectoryPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'database');
  }

  Future<Database> _initDb() async {
    final dbDir = await getDbDirectoryPath();
    // Buat folder 'database' jika belum ada
    final dir = Directory(dbDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final path = p.join(dbDir, 'auth_demo.db');

    return await openDatabase(
      path,
      version: 1, 
      onCreate: _onCreate,
    );
  }

  // Dijalankan jika database belum pernah ada sebelumnya
  Future _onCreate(Database db, int version) async {
    // Tabel Users
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        recovery_question TEXT,
        recovery_answer_hash TEXT,
        recovery_salt TEXT,
        created_at TEXT,
        last_activity TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_users_username ON users(username)');

    // Tabel Items
    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        description TEXT,
        limit_value REAL,
        uom TEXT,
        is_reminder INTEGER,
        reminder_limit REAL,
        created_at TEXT
      )
    ''');

    // Tabel Transaction
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER,
        item_code TEXT,
        document_id INTEGER,
        value REAL,
        date TEXT,
        created_at TEXT,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL
      )
    ''');

    // Tabel Documents
    await db.execute('''
      CREATE TABLE documents(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_number TEXT NOT NULL UNIQUE,
        created_at TEXT
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_doc_number ON documents(doc_number)');

    // Tabel Document Items (relasi many-to-many antara document & item)
    await db.execute('''
      CREATE TABLE document_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        limit_value REAL,
        uom TEXT,
        created_at TEXT,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_docitems_doc ON document_items(document_id)');
    await db.execute('CREATE INDEX idx_docitems_item ON document_items(item_id)');

    // Tabel Sessions (menyimpan data sesi login & biometrik)
    await db.execute('''
      CREATE TABLE sessions(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
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

  // Tambahkan fungsi untuk update aktivitas
  Future<void> updateLastActivity(String username) async {
    final db = await database;
    await db.update(
      'users',
      {'last_activity': DateTime.now().toIso8601String()},
      where: 'username = ?',
      whereArgs: [username.trim().toLowerCase()],
    );
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

  // Fungsi untuk mengambil data user lengkap berdasarkan username
  Future<Map<String, dynamic>?> getUserData(String username) async {
    final db = await database;
    final results = await db.query('users', where: 'username = ?', whereArgs: [username]);
    return results.isNotEmpty ? results.first : null;
  }

  // Fungsi untuk update nama
  Future<int> updateUserName(String username, String newName) async {
    final db = await database;
    return await db.update(
      'users',
      {'name': newName},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  /* ----------------------- CRUD TRANSACTIONS ----------------------- */

  // --- FUNGSI UPDATE DATA TRANSAKSI ---
  /// Memperbarui nilai dan tanggal transaksi berdasarkan ID
  Future<int> updateTransaction({required int id, required double value, required String date}) async {
    final db = await database;
    return await db.update(
      'transactions',
      {
        'value': value,
        'date': date,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- FUNGSI HAPUS DATA TRANSAKSI ---
  /// Menghapus baris transaksi secara permanen berdasarkan ID
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // --- FUNGSI UNTUK CEK APAKAH ADA USER (Digunakan di Splash Page) ---
  /// Menghitung jumlah user terdaftar untuk menentukan alur login/registrasi
  Future<bool> hasAnyUser() async {
    final db = await database;
    final List<Map<String, dynamic>> result = 
        await db.rawQuery('SELECT COUNT(*) as total FROM users');
    int? count = Sqflite.firstIntValue(result);
    return (count ?? 0) > 0;
  }

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('transactions', row);
  }

  // --- FUNGSI AMBIL SEMUA TRANSAKSI DENGAN JOIN ---
  Future<List<Map<String, dynamic>>> getAllTransactions() async {
    final db = await database;
    // JOIN items for description & documents for doc_number
    return await db.rawQuery('''
      SELECT t.*, i.description, i.limit_value,
             COALESCE(d.doc_number, '-') as doc_number
      FROM transactions t
      LEFT JOIN items i ON t.item_id = i.id
      LEFT JOIN documents d ON t.document_id = d.id
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

  /* ----------------------- CRUD DOCUMENTS ----------------------- */

  /// Cek apakah nomor dokumen sudah ada
  Future<bool> isDocNumberExists(String docNumber) async {
    final db = await database;
    final result = await db.query(
      'documents',
      where: 'doc_number = ?',
      whereArgs: [docNumber],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Insert dokumen baru, return id-nya
  Future<int> insertDocument(String docNumber, {String? date}) async {
    final db = await database;
    return await db.insert('documents', {
      'doc_number': docNumber.trim(),
      'created_at': date ?? DateTime.now().toIso8601String(),
    });
  }

  /// Ambil semua dokumen
  Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final db = await database;
    return await db.query('documents', orderBy: 'id DESC');
  }

  /// Hapus dokumen (dan relasi document_items akan terhapus via CASCADE)
  Future<int> deleteDocument(int id) async {
    final db = await database;
    return await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  /// Tambahkan item ke dokumen dengan limit & uom khusus dokumen
  Future<int> insertDocumentItem(int documentId, int itemId, {double? limitValue, String? uom}) async {
    final db = await database;
    return await db.insert('document_items', {
      'document_id': documentId,
      'item_id': itemId,
      'limit_value': limitValue,
      'uom': uom,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Hapus item dari dokumen
  Future<int> deleteDocumentItem(int id) async {
    final db = await database;
    return await db.delete('document_items', where: 'id = ?', whereArgs: [id]);
  }

  /// Ambil semua item dalam satu dokumen (JOIN dengan items) + consumed qty
  Future<List<Map<String, dynamic>>> getDocumentItems(int documentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT di.id as doc_item_id, di.document_id, di.item_id, di.created_at as added_at,
             di.limit_value as doc_limit_value, di.uom as doc_uom,
             i.code, i.description, i.limit_value as item_limit_value, i.uom as item_uom,
             i.is_reminder, i.reminder_limit,
             COALESCE((SELECT SUM(t.value) FROM transactions t WHERE t.item_id = di.item_id AND t.document_id = di.document_id), 0) as consumed
      FROM document_items di
      LEFT JOIN items i ON di.item_id = i.id
      WHERE di.document_id = ?
      ORDER BY di.id ASC
    ''', [documentId]);
  }

  /// Get all documents that contain a specific item (for dropdown in add record)
  Future<List<Map<String, dynamic>>> getDocumentsForItem(int itemId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.id, d.doc_number, di.limit_value as doc_limit_value, di.uom as doc_uom
      FROM document_items di
      JOIN documents d ON di.document_id = d.id
      WHERE di.item_id = ?
      ORDER BY d.doc_number ASC
    ''', [itemId]);
  }

  /// Get consumed quota: sum of transaction values for an item in a specific document
  Future<double> getConsumedQuota(int itemId, int documentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(value), 0) as total
      FROM transactions
      WHERE item_id = ? AND document_id = ?
    ''', [itemId, documentId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Cek apakah item sudah ada di dokumen tertentu
  Future<bool> isItemInDocument(int documentId, int itemId) async {
    final db = await database;
    final result = await db.query(
      'document_items',
      where: 'document_id = ? AND item_id = ?',
      whereArgs: [documentId, itemId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get total quota from all document_items (sum of limit_value)
  Future<double> getTotalDocumentQuota() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(limit_value), 0) as total FROM document_items
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get total consumed quota from all transactions
  Future<double> getTotalConsumedQuota() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(value), 0) as total FROM transactions
    ''');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Get all documents that contain a specific item, with limit, reminder, and consumed quota
  Future<List<Map<String, dynamic>>> getDocumentDetailsForItem(int itemId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT di.id as doc_item_id, di.document_id, di.item_id,
             di.limit_value as doc_limit_value, di.uom as doc_uom,
             d.doc_number, d.created_at as doc_date,
             i.is_reminder, i.reminder_limit,
             COALESCE((SELECT SUM(t.value) FROM transactions t WHERE t.item_id = di.item_id AND t.document_id = di.document_id), 0) as consumed
      FROM document_items di
      JOIN documents d ON di.document_id = d.id
      JOIN items i ON di.item_id = i.id
      WHERE di.item_id = ?
      ORDER BY d.doc_number ASC
    ''', [itemId]);
  }

  /// Check if a document has any transactions at all
  Future<bool> documentHasTransactions(int documentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM transactions
      WHERE document_id = ?
    ''', [documentId]);
    return (result.first['cnt'] as int? ?? 0) > 0;
  }

  /// Check if item has any transactions in a specific document
  Future<bool> hasTransactionsInDoc(int itemId, int documentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM transactions
      WHERE item_id = ? AND document_id = ?
    ''', [itemId, documentId]);
    return (result.first['cnt'] as int? ?? 0) > 0;
  }

  /// Update limit_value on a document_item
  Future<int> updateDocumentItem(int docItemId, {double? limitValue, String? uom}) async {
    final db = await database;
    final data = <String, dynamic>{};
    if (limitValue != null) data['limit_value'] = limitValue;
    if (uom != null) data['uom'] = uom;
    if (data.isEmpty) return 0;
    return await db.update('document_items', data, where: 'id = ?', whereArgs: [docItemId]);
  }

  /// Ambil semua dokumen beserta jumlah item
  Future<List<Map<String, dynamic>>> getAllDocumentsWithItemCount() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT d.*, COUNT(di.id) as item_count
      FROM documents d
      LEFT JOIN document_items di ON d.id = di.document_id
      GROUP BY d.id
      ORDER BY d.id DESC
    ''');
  }

  /* -------------------------- SESSION CRUD -------------------------- */

  /// Simpan atau update nilai session berdasarkan key
  Future<void> setSessionValue(String key, String value) async {
    final db = await database;
    await db.insert(
      'sessions',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Ambil nilai session berdasarkan key
  Future<String?> getSessionValue(String key) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Hapus satu session berdasarkan key
  Future<void> removeSessionValue(String key) async {
    final db = await database;
    await db.delete('sessions', where: 'key = ?', whereArgs: [key]);
  }

  /// Hapus semua data session
  Future<void> clearAllSessions() async {
    final db = await database;
    await db.delete('sessions');
  }
}