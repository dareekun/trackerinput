import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../data/db/app_db.dart'; // Import AppDb
import '../../data/session/session_manager.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    // 1. CEK APAKAH ADA USER TERDAFTAR DI DATABASE
    final bool isUserExists = await AppDb.instance.hasAnyUser();

    if (!isUserExists) {
      // Jika database kosong, paksa registrasi (First run)
      _goRoute('/register');
      return;
    }

    // 2. JIKA ADA USER, LANJUT CEK STATUS LOGIN & BIOMETRIK
    final current = await SessionManager.getCurrentUser();
    final bioEnabled = await SessionManager.isBiometricEnabled();
    final bioUser = await SessionManager.getBiometricUser();

    if (bioEnabled) {
      bool supported = false;
      try {
        final canCheck = await _auth.canCheckBiometrics;
        final isSupported = await _auth.isDeviceSupported();
        supported = canCheck || isSupported;
      } catch (_) {
        supported = false;
      }

      if (supported) {
        final ok = await _tryAuth(reason: 'Buka kunci aplikasi');
        if (ok) {
          if (current != null) {
            _goRoute('/dashboard');
            return;
          }
          if (bioUser != null) {
            await SessionManager.setCurrentUser(bioUser);
            _goRoute('/dashboard');
            return;
          }
        }
        // Gagal autentikasi biometrik, arahkan ke login manual
        _goRoute('/login');
        return;
      }
      
      // Jika biometric di-set aktif tapi device tidak support lagi
      await SessionManager.setBiometricEnabled(false);
    }

    // 3. LOGIKA NORMAL (Jika biometrik tidak aktif)
    if (current != null) {
      _goRoute('/dashboard');
    } else {
      _goRoute('/login');
    }
  }

  Future<bool> _tryAuth({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  void _goRoute(String route) {
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Menyiapkan aplikasi...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}