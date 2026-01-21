import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  
  @override
  Widget build(BuildContext context) {
  String? _email;

    final email = _email ?? '-';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
          const SizedBox(height: 12),
          Center(child: Text(email, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Ubah Password'),
            subtitle: const Text('Ganti password akun Anda'),
            onTap: () {
              context.go('/changepassword');
            },
          )
        ],
      ),
    );
  }
}
