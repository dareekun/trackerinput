
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

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
        _goRoute('/login');
        return;
      }

      // Tidak supported tapi status aktif → nonaktifkan agar tidak mentok
      await SessionManager.setBiometricEnabled(false);
    }

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
    // go_router: ganti seluruh location; memastikan shell aktif dan sidebar tetap
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
