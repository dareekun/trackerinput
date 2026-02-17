import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/session/session_manager.dart'; // Pastikan path benar
import '../../data/db/app_db.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _username = '-';
  String _name = 'User Baru';
  bool _isEditing = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final username = await SessionManager.getCurrentUser();
    if (username != null) {
      final userData = await AppDb.instance.getUserData(username);
      if (mounted) {
        setState(() {
          _username = username;
          _name = userData?['name'] ?? 'Guest';
          _nameController.text = _name;
        });
      }
    }
  }

  Future<void> _saveName() async {
    if (_nameController.text.trim().isEmpty) return;

    await AppDb.instance.updateUserName(_username, _nameController.text.trim());
    setState(() {
      _name = _nameController.text.trim();
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama berhasil diperbarui!')),
      );
    }
  }

  Future<void> _aboutpage() async {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tentang Aplikasi'),
        content: const Text('Copyright © Mada'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Bagian Header Profil
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: cs.primaryContainer,
                      child: Icon(Icons.person, size: 50, color: cs.primary),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Ubah Nama',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _saveName,
                        icon: const Icon(Icons.check, color: Colors.green),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _isEditing = false),
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _isEditing = true),
                            icon: const Icon(Icons.edit, size: 18),
                          ),
                        ],
                      ),
                      Text(_username, style: TextStyle(color: cs.outline)),
                    ],
                  ),
                //------------------
              ],
            ),
          ),

          const SizedBox(height: 32),
          // Judul Seksi
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              "PENGATURAN KEAMANAN",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Card Menu Keamanan
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.lock_reset_rounded, color: cs.primary),
                  title: const Text('Ubah Password'),
                  subtitle: const Text('Amankan akun dengan kata sandi baru'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    context.push(
                      '/changepassword',
                    ); // Menggunakan push agar bisa kembali
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Info Tambahan
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              _aboutpage();
            },
            icon: const Icon(Icons.info_outline),
            label: const Text("Tentang Aplikasi"),
          ),
        ],
      ),
    );
  }
}
