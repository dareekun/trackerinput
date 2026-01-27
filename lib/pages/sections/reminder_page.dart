import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';
import '../../data/services/notification_service.dart';

class ReminderPage extends StatelessWidget {
  const ReminderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Item Melebihi Limit"),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AppDb.instance.database.then((db) => NotificationService.getOverLimitItems(db)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Semua item masih dalam batas aman."));
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                  title: Text("${item['code']} - ${item['description'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Digunakan: ${item['total_used']}"),
                      Text("Batas Limit: ${item['limit_value']}", style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}