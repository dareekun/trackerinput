import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';

class DetailHistoryPage extends StatelessWidget {
  final String? filterDate; // Format: YYYY-MM-DD

  const DetailHistoryPage({super.key, this.filterDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(filterDate == null ? 'Semua Riwayat' : 'Riwayat: $filterDate'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AppDb.instance.getAllTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          // Filter data berdasarkan tanggal yang dikirim dari kalender
          final list = snapshot.data!.where((tx) {
            if (filterDate == null) return true;
            return tx['date'].toString().contains(filterDate!);
          }).toList();

          if (list.isEmpty) {
            return const Center(child: Text("Tidak ada transaksi pada tanggal ini."));
          }

          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.history)),
                title: Text("${item['item_code']} - ${item['description'] ?? ''}"),
                subtitle: Text("Tanggal: ${item['date']}"),
                trailing: Text(
                  "${item['value']}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              );
            },
          );
        },
      ),
    );
  }
}