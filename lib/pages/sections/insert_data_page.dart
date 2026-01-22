import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';

class InsertDataPage extends StatefulWidget {
  const InsertDataPage({super.key});

  @override
  State<InsertDataPage> createState() => _InsertDataPageState();
}

class _InsertDataPageState extends State<InsertDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _limitController = TextEditingController();
  final _reminderLimitController = TextEditingController();
  bool _isReminderActive = false;

  @override
  void dispose() {
    _codeController.dispose();
    _descController.dispose();
    _limitController.dispose();
    _reminderLimitController.dispose();
    super.dispose();
  }

  // FUNGSI UNTUK RESET FORM
  void _clearForm() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _descController.clear();
    _limitController.clear();
    _reminderLimitController.clear();
    setState(() {
      _isReminderActive = false;
    });
  }

  // FUNGSI SUBMIT DENGAN SQLITE
  Future<void> _submitData() async {
  if (_formKey.currentState!.validate()) {
    try {
      final String code = _codeController.text.trim();

      // 1. VALIDASI DUPLIKASI: Cek ke SQLite
      bool isDuplicate = await AppDb.instance.isItemCodeExists(code);

      if (isDuplicate) {
        if (!mounted) return;
        // Tampilkan peringatan jika duplikat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Item Code "$code" sudah terdaftar!'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // Hentikan proses simpan
      }

      // 2. Jika tidak duplikat, lanjutkan simpan
      final Map<String, dynamic> row = {
        'code': code,
        'description': _descController.text,
        'limit_value': double.tryParse(_limitController.text) ?? 0.0,
        'is_reminder': _isReminderActive ? 1 : 0,
        'reminder_limit': _isReminderActive 
            ? (double.tryParse(_reminderLimitController.text) ?? 0.0) 
            : 0.0,
      };

      await AppDb.instance.insertItem(row);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil menyimpan data ke database!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _clearForm();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Insert New Item", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Item Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Limit Value', border: OutlineInputBorder(), prefixIcon: Icon(Icons.summarize)),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onChanged: (_) => _isReminderActive ? _formKey.currentState!.validate() : null,
              ),
              const SizedBox(height: 24),

              // Bagian Reminder
              Card(
                elevation: 0,
                color: cs.surfaceVariant.withOpacity(0.3),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Activate Reminder"),
                      value: _isReminderActive,
                      onChanged: (val) => setState(() => _isReminderActive = val),
                    ),
                    if (_isReminderActive)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _reminderLimitController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Reminder Limit', border: OutlineInputBorder()),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            double? limit = double.tryParse(_limitController.text);
                            double? reminder = double.tryParse(value);
                            if (limit != null && reminder != null && reminder > limit) {
                              return 'Cannot exceed Limit Value ($limit)';
                            }
                            return null;
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submitData,
                  icon: const Icon(Icons.save),
                  label: const Text("SUBMIT DATA"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}