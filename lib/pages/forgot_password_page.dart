
import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _usernameCtl = TextEditingController();
  final _answerCtl = TextEditingController();
  final _newPassCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  String? _question;
  bool _step2 = false;
  bool _isLoading = false;
  bool _ob1 = true;
  bool _ob2 = true;

  @override
  void dispose() {
    _usernameCtl.dispose();
    _answerCtl.dispose();
    _newPassCtl.dispose();
    _confirmCtl.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestion() async {
    final username = _usernameCtl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan username terlebih dahulu.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final q = await AuthRepository.instance.getRecoveryQuestion(username);
      if (!mounted) return;
      if (q == null || q.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akun tidak memiliki pertanyaan pemulihan.')));
      } else {
        setState(() {
          _question = q;
          _step2 = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final username = _usernameCtl.text.trim();
    final answer = _answerCtl.text.trim();
    final p1 = _newPassCtl.text;
    final p2 = _confirmCtl.text;
    if (answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jawaban pemulihan wajib diisi.')));
      return;
    }
    if (p1.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password baru minimal 6 karakter.')));
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konfirmasi password tidak sama.')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ok = await AuthRepository.instance.resetPasswordWithRecovery(
        username: username,
        recoveryAnswer: answer,
        newPassword: p1,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil direset. Silakan login.')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jawaban salah atau akun tidak valid.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameCtl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            if (!_step2) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _fetchQuestion,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Lanjut'),
                ),
              ),
            ],
            if (_step2) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Pertanyaan pemulihan:', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_question ?? '-', style: Theme.of(context).textTheme.bodyLarge),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answerCtl,
                decoration: const InputDecoration(
                  labelText: 'Jawaban Anda',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPassCtl,
                decoration: InputDecoration(
                  labelText: 'Password baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _ob1 = !_ob1),
                    icon: Icon(_ob1 ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                obscureText: _ob1,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtl,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi password baru',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _ob2 = !_ob2),
                    icon: Icon(_ob2 ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                obscureText: _ob2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Reset Password'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}