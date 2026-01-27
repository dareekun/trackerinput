import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _questionCtl = TextEditingController();
  final _answerCtl = TextEditingController();

  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  // State untuk mengontrol alur tampilan
  bool _showForm = false;

  @override
  void dispose() {
    _nameCtl.dispose();
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
        name: _nameCtl.text.trim(),
        email: _emailCtl.text.trim(),
        password: _passwordCtl.text,
        recoveryQuestion: _questionCtl.text.trim().isEmpty
            ? null
            : _questionCtl.text,
        recoveryAnswer: _questionCtl.text.trim().isEmpty
            ? null
            : _answerCtl.text,
      );

      if (!mounted) return;
      if (ok) {
        // Tampilkan pesan sukses
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registrasi berhasil! Silakan masuk dengan akun baru Anda.',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email sudah terdaftar. Gunakan email lain.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      // Tombol Back hanya muncul jika form sedang ditampilkan
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _showForm
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => setState(() => _showForm = false),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: !_showForm ? _buildWelcomeSection(cs) : _buildRegisterForm(cs),
      ),
    );
  }

  // --- 1. TAMPILAN ANIMASI SELAMAT DATANG ---
  Widget _buildWelcomeSection(ColorScheme cs) {
    return Center(
      key: const ValueKey('welcome'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon atau Logo Animasi
            TweenAnimationBuilder(
              duration: const Duration(seconds: 1),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(scale: value, child: child),
                );
              },
              child: Icon(
                Icons.app_registration_rounded,
                size: 100,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Selamat Datang!",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Mulai catat transaksi Anda dengan lebih teratur dan aman bersama kami.",
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline, fontSize: 16),
            ),
            const SizedBox(height: 48),
            // Tombol untuk memunculkan form
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.arrow_forward),
              label: const Text(
                "Daftar Sekarang",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. TAMPILAN FORM REGISTRASI ---
  Widget _buildRegisterForm(ColorScheme cs) {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Buat Akun Baru",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Lengkapi data di bawah untuk memulai.",
              style: TextStyle(color: cs.outline),
            ),
            const SizedBox(height: 32),

            _buildField(
              controller: _nameCtl,
              label: "Nama Lengkap",
              icon: Icons.person_outline,
              capitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _emailCtl,
              label: "Email",
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Email wajib diisi';
                if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$').hasMatch(s))
                  return 'Format tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildPasswordField(
              controller: _passwordCtl,
              label: "Password",
              isObscure: _obscure1,
              toggle: () => setState(() => _obscure1 = !_obscure1),
              validator: (v) =>
                  (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 16),

            _buildPasswordField(
              controller: _confirmCtl,
              label: "Konfirmasi Password",
              isObscure: _obscure2,
              toggle: () => setState(() => _obscure2 = !_obscure2),
              validator: (v) =>
                  v != _passwordCtl.text ? 'Password tidak cocok' : null,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(),
            ),

            // Seksi Pemulihan
            Text(
              "Keamanan Tambahan",
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _questionCtl,
              label: "Pertanyaan Pemulihan",
              icon: Icons.help_outline,
              hint: "Contoh: Nama kecil Anda?",
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _answerCtl,
              label: "Jawaban",
              icon: Icons.vpn_key_outlined,
            ),

            const SizedBox(height: 40),

            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _handleRegister,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Konfirmasi Pendaftaran',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS DENGAN STYLE OUTLINED ---
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? type,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        // Menggunakan OutlineInputBorder agar label berada di garis saat fokus
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isObscure,
    required VoidCallback toggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off),
          onPressed: toggle,
        ),
        // Style Outlined
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }
}
