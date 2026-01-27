import 'package:sqflite/sqflite.dart';

class NotificationService {
  // Fungsi hitung yang sudah ada
  static Future<int> getLimitReminderCount(Database db) async {
    try {
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT COUNT(*) as total 
        FROM items i
        JOIN (
          SELECT item_code, SUM(value) as total_used 
          FROM transactions 
          GROUP BY item_code
        ) t ON i.code = t.item_code
        WHERE t.total_used >= i.limit_value 
           OR (i.is_reminder = 1 AND t.total_used >= i.reminder_limit)
      ''');
      return result.isNotEmpty ? (result.first['total'] as int) : 0;
    } catch (e) {
      return 0;
    }
  }

  // --- FUNGSI BARU: Ambil Daftar Item yang Melebihi Limit ---
  static Future<List<Map<String, dynamic>>> getOverLimitItems(Database db) async {
    try {
      return await db.rawQuery('''
        SELECT 
          i.code, 
          i.description, 
          i.limit_value, 
          i.reminder_limit,
          t.total_used
        FROM items i
        JOIN (
          SELECT item_code, SUM(value) as total_used 
          FROM transactions 
          GROUP BY item_code
        ) t ON i.code = t.item_code
        WHERE t.total_used >= i.limit_value 
           OR (i.is_reminder = 1 AND t.total_used >= i.reminder_limit)
      ''');
    } catch (e) {
      print("Error detail notifikasi: $e");
      return [];
    }
  }
}