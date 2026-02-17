
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart'; // <— Tambah ini

import '../../data/db/app_db.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/session/session_manager.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  // Biometrik
  final _auth = LocalAuthentication();
  bool _bioAvailable = false;
  String? _bioUser;

  @override
  void initState() {
    super.initState();
    _prepareBio();
  }

  Future<void> _prepareBio() async {
    try {
      final enabled = await SessionManager.isBiometricEnabled();
      final user = await SessionManager.getBiometricUser();
      final can = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!mounted) return;
      setState(() {
        _bioAvailable = enabled && user != null && (can || supported);
        _bioUser = user;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bioAvailable = false;
        _bioUser = null;
      });
    }
  }

  @override
  void dispose() {
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final ok = await AuthRepository.instance.login(
        _usernameCtl.text,
        _passwordCtl.text,
      );
      if (!mounted) return;
      if (ok) {
        await SessionManager.setCurrentUser(_usernameCtl.text);
        // === PENTING: arahkan ke rute shell, bukan dorong widget ===
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username atau password salah.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateUsername(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Username wajib diisi';
    if (s.length < 3) return 'Username minimal 3 karakter';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'Password wajib diisi';
    if ((v!).length < 6) return 'Minimal 6 karakter';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 400 : 600),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 64, color: Colors.indigo),
                      const SizedBox(height: 16),
                      Text('Masuk', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameCtl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: _validateUsername,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordCtl,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        validator: _validatePassword,
                        obscureText: _obscure,
                        onFieldSubmitted: (_) => _handleLogin(),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
                            },
                            child: const Text('Lupa password?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Masuk'),
                        ),
                      ),
                      if (_bioAvailable) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Masuk dengan Biometrik'),
                            onPressed: _isLoading ? null : () async {
                              try {
                                final ok = await _auth.authenticate(
                                  localizedReason: 'Autentikasi untuk masuk',
                                  options: const AuthenticationOptions(
                                    biometricOnly: true,
                                    stickyAuth: true,
                                    useErrorDialogs: true,
                                  ),
                                );
                                if (!ok) return;
                                if (_bioUser != null) {
                                  await SessionManager.setCurrentUser(_bioUser!);
                                  if (!mounted) return;
                                  // === PENTING: arahkan ke rute shell ===
                                  context.go('/dashboard');
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal autentikasi: $e')));
                              }
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Secret debug button — hanya muncul di debug/profile mode
                      if (kDebugMode) ...[  
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final dbPath = await AppDb.instance.getDbDirectoryPath();
                              if (!context.mounted) return;
                              
                              // Coba buka folder langsung di desktop
                              if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
                                final String command;
                                final List<String> args;
                                if (Platform.isMacOS) {
                                  command = 'open';
                                  args = [dbPath];
                                } else if (Platform.isWindows) {
                                  command = 'explorer';
                                  args = [dbPath];
                                } else {
                                  command = 'xdg-open';
                                  args = [dbPath];
                                }
                                await Process.run(command, args);
                              } else {
                                // Di mobile, tampilkan path di dialog
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Database Location'),
                                    content: SelectableText(dbPath),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('DB Location', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
