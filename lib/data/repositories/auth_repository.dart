import 'package:sqflite/sqflite.dart';
import '../db/app_db.dart';
import '../models/user.dart';
import '../../utils/crypto_util.dart';

class AuthRepository {
  AuthRepository._internal();
  static final AuthRepository instance = AuthRepository._internal();

  Future<Database> get _db async => AppDb.instance.database;

  Future<bool> register({
    required String email,
    required String password,
    String? recoveryQuestion,
    String? recoveryAnswer,
  }) async {
    final db = await _db;

    final salt = CryptoUtil.generateSalt(16);
    final passwordHash = CryptoUtil.hashWithSalt(password, salt);

    String? rSalt;
    String? rHash;
    if (recoveryQuestion != null && recoveryQuestion.trim().isNotEmpty && recoveryAnswer != null) {
      rSalt = CryptoUtil.generateSalt(16);
      rHash = CryptoUtil.hashWithSalt(recoveryAnswer.trim(), rSalt);
    }

    try {
      await db.insert('users', {
        'email': email.trim().toLowerCase(),
        'password_hash': passwordHash,
        'salt': salt,
        'recovery_question': recoveryQuestion?.trim(),
        'recovery_answer_hash': rHash,
        'recovery_salt': rSalt,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } on DatabaseException catch (e) {
      // Cek UNIQUE constraint gagal
      if (e.isUniqueConstraintError()) return false;
      rethrow;
    }
  }

  Future<bool> login(String email, String password) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final user = User.fromMap(rows.first);
    return CryptoUtil.verify(password, user.salt, user.passwordHash);
  }

  Future<String?> getRecoveryQuestion(String email) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      columns: ['recovery_question'],
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['recovery_question'] as String?;
  }

  Future<bool> resetPasswordWithRecovery({
    required String email,
    required String recoveryAnswer,
    required String newPassword,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final u = User.fromMap(rows.first);

    if (u.recoverySalt == null || u.recoveryAnswerHash == null) {
      return false; // tidak ada recovery info
    }

    final ok = CryptoUtil.verify(recoveryAnswer.trim(), u.recoverySalt!, u.recoveryAnswerHash!);
    if (!ok) return false;

    // update password
    final newSalt = CryptoUtil.generateSalt(16);
    final newHash = CryptoUtil.hashWithSalt(newPassword, newSalt);
    final count = await db.update(
      'users',
      {'password_hash': newHash, 'salt': newSalt},
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    return count == 1;
  }

  Future<bool> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final u = User.fromMap(rows.first);

    final ok = CryptoUtil.verify(oldPassword, u.salt, u.passwordHash);
    if (!ok) return false;

    final newSalt = CryptoUtil.generateSalt(16);
    final newHash = CryptoUtil.hashWithSalt(newPassword, newSalt);
    final count = await db.update(
      'users',
      {'password_hash': newHash, 'salt': newSalt},
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    return count == 1;
  }
}