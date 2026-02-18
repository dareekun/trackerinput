import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/db/app_db.dart';
import '../../data/session/refresh_notifier.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _selectedDate = DateTime.now();

  // Variabel data dinamis
  int _itemCount = 0;
  double _totalQuota = 0;
  double _consumedQuota = 0;
  double _remainingQuota = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  /// Fungsi untuk mengambil dan menghitung data dari database secara real-time
  Future<void> _loadStats() async {
    final items = await AppDb.instance.getAllItems();

    // Calculate total quota from document_items (per-document limits)
    final quotaSum = await AppDb.instance.getTotalDocumentQuota();
    final consumedSum = await AppDb.instance.getTotalConsumedQuota();

    if (mounted) {
      setState(() {
        _itemCount = items.length;
        _totalQuota = quotaSum;
        _consumedQuota = consumedSum;
        _remainingQuota = _totalQuota - _consumedQuota;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ValueListenableBuilder mendengarkan sinyal dari RefreshNotifier.triggerRefresh()
    return ValueListenableBuilder(
      valueListenable: RefreshNotifier.refreshCounter,
      builder: (context, value, child) {
        return FutureBuilder(
          future: _loadStats(),
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  // --- BARIS KARTU STATISTIK ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                    children: [
                      _StatCard(
                        label: 'Items Registered',
                        value: '$_itemCount Items',
                        icon: Icons.inventory_2_outlined,
                      ),
                      _StatCard(
                        label: 'Total Quota',
                        value: _totalQuota.toStringAsFixed(0),
                        icon: Icons.all_inbox_sharp,
                      ),
                      _StatCard(
                        label: 'Quota Usage',
                        value: _consumedQuota.toStringAsFixed(0),
                        icon: Icons.data_usage_rounded,
                      ),
                      _StatCard(
                        label: 'Remaining Quota',
                        value: _remainingQuota.toStringAsFixed(0),
                        icon: Icons.pie_chart_outline_rounded,
                        valueColor: _remainingQuota <= 0 ? Colors.red : cs.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- VISUALISASI PROGRESS QUOTA ---
                  _PaneCard(
                    title: 'Sisa Quota: ${_totalQuota == 0 ? 0 : ((_consumedQuota / _totalQuota) * 100).toStringAsFixed(1)}% Terpakai',
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _totalQuota == 0 ? 0 : (_consumedQuota / _totalQuota),
                            minHeight: 12,
                            backgroundColor: cs.surfaceContainerHighest,
                            color: _remainingQuota <= 0 ? Colors.red : cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- KALENDER AKTIVITAS ---
                  _PaneCard(
                    title: 'Schedule & Activity',
                    child: SizedBox(
                      height: 360,
                      child: CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2090),
                        onDateChanged: (newDate) {
                          setState(() => _selectedDate = newDate);

                          // Format tanggal untuk parameter navigasi ke History
                          final dateStr =
                              "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";
                          
                          // Pindah ke halaman detail history berdasarkan tanggal yang dipilih
                          context.push('/detailhistory?date=$dateStr');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- WIDGET STAT CARD (Gaya Modern) ---
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer.withOpacity(0.3),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: valueColor ?? cs.onSurface,
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

// --- WIDGET PANE CARD (Container Bagian) ---
class _PaneCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _PaneCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}