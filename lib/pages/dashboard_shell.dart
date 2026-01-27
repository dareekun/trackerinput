import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/session/session_manager.dart';
import '../../data/services/notification_service.dart';
import '../data/db/app_db.dart';

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
  int _reminderCount = 0; // Variable didefinisikan di sini

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
    _refreshNotification();
  }

  Future<void> _loadUser() async {
    try {
      final email = await SessionManager.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _email = email ?? "Guest User";
      });
    } catch (e) {
      debugPrint("Gagal memuat session: $e");
      setState(() => _email = "Error User");
    }
  }

  Future<void> _refreshNotification() async {
    try {
      final db = await AppDb.instance.database;
      final count = await NotificationService.getLimitReminderCount(db);

      if (!mounted) return;
      setState(() {
        _reminderCount = count;
      });
    } catch (e) {
      debugPrint("Gagal update lonceng: $e");
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
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await SessionManager.clear();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final activeItem = _menuItems[widget.navShell.currentIndex];

    return Listener(
      onPointerDown: (_) {
        // Setiap kali layar disentuh, reset timer!
        SessionManager.startTimeoutTimer();
        // Update juga di DB (opsional, jangan terlalu sering agar tidak berat)
      },
      child: Scaffold(
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
                  // PERBAIKAN: Melemparkan variable _reminderCount ke _HeaderBar
                  _HeaderBar(
                    title: activeItem.label,
                    email: _email ?? 'User',
                    reminderCount: _reminderCount,
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: widget.navShell,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const ListTile(
          leading: Icon(Icons.menu_open, size: 28),
          title: Text(
            "MAIN MENU",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
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
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  widget.navShell.goBranch(index);
                  if (MediaQuery.of(context).size.width < 1100) {
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
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
  final int reminderCount; // Tambahkan parameter di sini

  const _HeaderBar({
    required this.title,
    required this.email,
    required this.reminderCount, // Wajib diisi
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: cs.surface,
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),

          // PERBAIKAN: Menampilkan Badge hanya jika reminderCount > 0
          IconButton(
            onPressed: () {
              context.push('/reminder');
            },
            icon: reminderCount > 0
                ? Badge(
                    label: Text(
                      reminderCount.toString(),
                    ), // Convert int ke String
                    child: Icon(
                      Icons.notifications_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.notifications_outlined,
                    color: cs.onSurfaceVariant,
                  ),
          ),

          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primary,
                  child: const Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
