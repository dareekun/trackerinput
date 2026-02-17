import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../db/app_db.dart';
import '../../main.dart';   // Import navigatorKey dari main.dart

class SessionManager {
  static const _keyCurrentUser = 'current_user';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyBiometricUser = 'biometric_user';

  static Timer? _sessionTimer;
  // Tentukan durasi timeout (misal: 5 menit)
  static const int _timeoutMinutes = 60;

  // ===== Sesi login =====
  static Future<void> setCurrentUser(String username) async {
    await AppDb.instance.setSessionValue(_keyCurrentUser, username.trim().toLowerCase());
    await AppDb.instance.updateLastActivity(username);
    startTimeoutTimer(); // Mulai timer saat login
  }

  static Future<String?> getCurrentUser() async {
    return await AppDb.instance.getSessionValue(_keyCurrentUser);
  }

  static Future<void> clear() async {
    _sessionTimer?.cancel(); // Matikan timer
    await AppDb.instance.removeSessionValue(_keyCurrentUser);
  }

  // ===== LOGIKA TIMEOUT =====

  static void startTimeoutTimer() {
    _sessionTimer?.cancel(); // Hentikan timer sebelumnya jika ada
    
    _sessionTimer = Timer(const Duration(minutes: _timeoutMinutes), () async {
      await forceLogout();
    });
  }

  static Future<void> forceLogout() async {
    // 1. Ambil context dari navigatorKey
    final context = navigatorKey.currentContext;
    
    // 2. Hapus data sesi
    await clear();

    if (context != null && context.mounted) {
      // 3. Tampilkan Pesan SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session Time Out!"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );

      // 4. Tendang ke halaman login
      context.go('/login');
    }
  }

  // ===== Preferensi biometrik =====
  static Future<void> setBiometricEnabled(bool enabled) async {
    await AppDb.instance.setSessionValue(_keyBiometricEnabled, enabled.toString());
  }

  static Future<bool> isBiometricEnabled() async {
    final val = await AppDb.instance.getSessionValue(_keyBiometricEnabled);
    return val == 'true';
  }

  static Future<void> setBiometricUser(String username) async {
    await AppDb.instance.setSessionValue(_keyBiometricUser, username.trim().toLowerCase());
  }

  static Future<String?> getBiometricUser() async {
    return await AppDb.instance.getSessionValue(_keyBiometricUser);
  }

  static Future<void> clearBiometric() async {
    await AppDb.instance.removeSessionValue(_keyBiometricEnabled);
    await AppDb.instance.removeSessionValue(_keyBiometricUser);
  }
}