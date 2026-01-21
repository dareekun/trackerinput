
import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _questionCtl = TextEditingController();
  final _answerCtl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    _questionCtl.dispose();
    _answerCtl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final ok = await AuthRepository.instance.register(
        email: _emailCtl.text,
        password: _passwordCtl.text,
        recoveryQuestion: _questionCtl.text.trim().isEmpty ? null : _questionCtl.text,
        recoveryAnswer: _questionCtl.text.trim().isEmpty ? null : _answerCtl.text,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registrasi berhasil. Silakan login.')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sudah terdaftar.')));
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
      appBar: AppBar(title: const Text('Daftar')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _emailCtl,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Email wajib diisi';
                final re = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$');
                if (!re.hasMatch(s)) return 'Format email tidak valid';
                return null;
              },
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtl,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                  icon: Icon(_obscure1 ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              obscureText: _obscure1,
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Password wajib diisi';
                if (v!.length < 6) return 'Minimal 6 karakter';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtl,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                  icon: Icon(_obscure2 ? Icons.visibility : Icons.visibility_off),
                ),
              ),
              obscureText: _obscure2,
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Konfirmasi password wajib diisi';
                if (v != _passwordCtl.text) return 'Password tidak sama';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            // Optional recovery (disarankan diisi agar lupa password bisa reset)
            TextFormField(
              controller: _questionCtl,
              decoration: const InputDecoration(
                labelText: 'Pertanyaan pemulihan (opsional)',
                hintText: 'Contoh: Nama hewan peliharaan pertama saya?',
                prefixIcon: Icon(Icons.help_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _answerCtl,
              decoration: const InputDecoration(
                labelText: 'Jawaban pemulihan (opsional, isi jika pertanyaan diisi)',
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Daftar'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
