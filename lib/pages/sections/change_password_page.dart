import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/session/session_manager.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isObscureOld = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      try {
        // 1. Logika Update di Database (Asumsi Anda memanggil fungsi update di AppDb)
        // final db = await AppDb.instance.database;
        // await AppDb.instance.updatePassword(_newPassController.text);

        // 2. Tampilkan notifikasi sukses
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password berhasil diperbarui. Silakan login kembali.'),
            backgroundColor: Colors.green,
          ),
        );

        // 3. HAPUS SESI (Logout Paksa)
        await SessionManager.clear();

        // 4. KEMBALI KE LOGIN
        // Kita gunakan .go agar stack navigasi dashboard dihapus total
        if (!mounted) return;
        context.go('/login');
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui password: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              "Buat password baru yang kuat untuk melindungi akun Anda.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // INPUT PASSWORD LAMA
            TextFormField(
              controller: _oldPassController,
              obscureText: _isObscureOld,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_isObscureOld ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isObscureOld = !_isObscureOld),
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Masukkan password lama' : null,
            ),
            const SizedBox(height: 16),

            // INPUT PASSWORD BARU
            TextFormField(
              controller: _newPassController,
              obscureText: _isObscureNew,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                prefixIcon: const Icon(Icons.lock_open_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_isObscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isObscureNew = !_isObscureNew),
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v!.length < 6 ? 'Minimal 6 karakter' : null,
            ),
            const SizedBox(height: 16),

            // KONFIRMASI PASSWORD BARU
            TextFormField(
              controller: _confirmPassController,
              obscureText: _isObscureConfirm,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                prefixIcon: const Icon(Icons.check_circle_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isObscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != _newPassController.text) return 'Password tidak cocok';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // TOMBOL SIMPAN
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleUpdate,
              child: const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}