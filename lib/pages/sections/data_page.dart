import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';
// import 'package:go_router/go_router.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  Future<void> _refreshData() async {
    setState(() {});
  }

  // Fungsi untuk menghapus data dengan konfirmasi
  Future<void> _confirmDelete(int id, String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Apakah Anda yakin ingin menghapus item "$code"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDb.instance.deleteItem(id);
      _refreshData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil dihapus'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: AppDb.instance.getAllItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: cs.outline),
                    const SizedBox(height: 16),
                    const Text("Belum ada data history."),
                  ],
                ),
              );
            }

            final items = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("Item Management", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withOpacity(0.3)),
                      columns: const [
                          DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Limit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Reminder', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: items.map((item) {
                        return DataRow(cells: [
                          DataCell(Text(item['code'].toString())),
                          DataCell(Text(item['description'] ?? '-')),
                          DataCell(Text(item['limit_value']?.toString() ?? '0')),
                          DataCell(Text(item['is_reminder'] == 1 ? item['reminder_limit'].toString() : "-")),
                          DataCell(
                            Row(
                              children: [
                                // TOMBOL UPDATE
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    // Logika: Kirim data ke page insert untuk diedit
                                    // context.go('/insertdata', extra: item); 
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Edit segera hadir")));
                                  },
                                ),
                                // TOMBOL HAPUS
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _confirmDelete(item['id'], item['code']),
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}