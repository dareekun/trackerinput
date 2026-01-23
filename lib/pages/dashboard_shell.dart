import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// Ganti dengan path session_manager Anda yang sebenarnya
import '../../data/session/session_manager.dart';

/// Model sederhana untuk menu agar mudah dikelola
class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class DashboardShell extends StatefulWidget {
  final StatefulNavigationShell navShell;
  const DashboardShell({super.key, required this.navShell});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  String? _email;

  // DAFTAR MENU: Urutan di sini HARUS sama dengan urutan branch di GoRouter Anda
  final List<NavItem> _menuItems = const [
    NavItem(Icons.dashboard_outlined, 'Dashboard'),
    NavItem(Icons.edit_outlined, 'Register Item'),
    NavItem(Icons.article_outlined, 'Data List'),
    NavItem(Icons.apps_outlined, 'Add Data'),
    NavItem(Icons.history, 'History'),
    NavItem(Icons.account_circle_outlined, 'Account'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

Future<void> _loadUser() async {
    try {
      // 1. Ambil email asli dari SessionManager
      final email = await SessionManager.getCurrentUser();
      
      if (!mounted) return;

      // 2. Jika email ditemukan, update state. Jika tidak (null), beri fallback.
      setState(() {
        _email = email ?? "Guest User"; 
      });
    } catch (e) {
      debugPrint("Gagal memuat session: $e");
      setState(() => _email = "Error User");
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Batal')
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Keluar')
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 3. Hapus data session di storage
    await SessionManager.clear();

    if (!mounted) return;

    // 4. Arahkan kembali ke login dan hapus stack navigasi
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 1100;
    
    // MENDAPATKAN JUDUL AKTIF: Berdasarkan index branch go_router yang sedang terbuka
    final activeItem = _menuItems[widget.navShell.currentIndex];

    return Scaffold(
      appBar: isWide ? null : AppBar(title: Text(activeItem.label)),
      drawer: isWide ? null : Drawer(child: _buildSidebar(context)),
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(right: BorderSide(color: cs.outlineVariant)),
              ),
              child: SafeArea(child: _buildSidebar(context)),
            ),
          Expanded(
            child: Column(
              children: [
                // Header Bar dengan Judul Dinamis
                _HeaderBar(
                  title: activeItem.label, 
                  email: _email ?? 'User',
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                    ),
                    child: widget.navShell,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi Sidebar yang terintegrasi
  Widget _buildSidebar(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const ListTile(
          leading: Icon(Icons.menu_open, size: 28),
          title: Text("MAIN MENU", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              final item = _menuItems[index];
              final isSelected = widget.navShell.currentIndex == index;
              return ListTile(
                selected: isSelected,
                leading: Icon(isSelected ? item.icon : item.icon), // Bisa ganti icon jika aktif
                title: Text(item.label),
                onTap: () {
                  widget.navShell.goBranch(index);
                  if (MediaQuery.of(context).size.width < 1100) Navigator.pop(context);
                },
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text("Sign Out"),
          ),
        ),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final String email;
  const _HeaderBar({required this.title, required this.email});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: cs.surface,
      child: Row(
        children: [
          // TULISAN INI BERUBAH OTOMATIS
          Text(
            title, 
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 14, backgroundColor: cs.primary, child: const Icon(Icons.person, size: 16, color: Colors.white)),
                const SizedBox(width: 8),
                Text(email, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}