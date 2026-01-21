
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/session/session_manager.dart';

class DashboardShell extends StatefulWidget {
  final StatefulNavigationShell navShell;
  const DashboardShell({super.key, required this.navShell});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final email = await SessionManager.getCurrentUser();
    if (!mounted) return;
    setState(() => _email = email ?? 'User');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (confirm != true) return;

    await SessionManager.clear();
    if (!mounted) return;
    context.go('/login'); // arahkan ke login tanpa menumpuk stack
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;

    final sidebar = _Sidebar(
      currentIndex: widget.navShell.currentIndex,
      onSelect: (i) {
        // Pindah branch tanpa reset stack internal
        widget.navShell.goBranch(i);
      },
      onLogout: _logout,
    );

    return Scaffold(
      // AppBar minimal hanya untuk mobile/tablet
      appBar: isWide ? null : AppBar(
        title: const Text('Dashboard'),
      ),
      drawer: isWide ? null : Drawer(child: sidebar),
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              child: SafeArea(child: sidebar),
            ),
          // Konten halaman dinamis
          Expanded(
            child: Column(
              children: [
                _HeaderBar(email: _email ?? 'User'),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainerLowest,
                      child: SafeArea(top: false, child: widget.navShell),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------- Sidebar -------------------------------- */

class _Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.currentIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final items = const [
      (_IconLabel(Icons.dashboard_outlined, 'Dashboard'), '/dashboard'),
      (_IconLabel(Icons.edit_outlined, 'insert Data'), '/insertdata'),
      (_IconLabel(Icons.article_outlined, 'Data'), '/data'),
      (_IconLabel(Icons.chat_bubble_outline, 'Chat'), '/chat'),
      (_IconLabel(Icons.apps_outlined, 'App'), '/app'),
      (_IconLabel(Icons.account_circle_outlined, 'Account'), '/account'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.menu, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Menu', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final selected = i == currentIndex;
                return _SidebarTile(
                  icon: items[i].$1.icon,
                  label: items[i].$1.label,
                  selected: selected,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: onLogout,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLabel {
  final IconData icon;
  final String label;
  const _IconLabel(this.icon, this.label);
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer.withOpacity(0.45) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
        title: Text(label, style: TextStyle(color: selected ? cs.onPrimaryContainer : cs.onSurface)),
        onTap: onTap,
      ),
    );
  }
}

/* -------------------------------- Header -------------------------------- */

class _HeaderBar extends StatelessWidget {
  final String email;
  const _HeaderBar({required this.email});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go('/account'),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primary,
                  child: const Icon(Icons.person, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Text(email, style: TextStyle(color: cs.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
