
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _keyCurrentUser = 'current_user';
  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyBiometricUser = 'biometric_user';

  // ===== Sesi login =====
  static Future<void> setCurrentUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, email.trim().toLowerCase());
  }

  static Future<String?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrentUser);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
  }

  // ===== Preferensi biometrik =====
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  static Future<void> setBiometricUser(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBiometricUser, email.trim().toLowerCase());
  }

  static Future<String?> getBiometricUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBiometricUser);
  }

  static Future<void> clearBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBiometricEnabled);
    await prefs.remove(_keyBiometricUser);
  }
}