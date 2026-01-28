import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';
import '../../data/session/refresh_notifier.dart';

class RegisterItemPage extends StatefulWidget {
  const RegisterItemPage({super.key});

  @override
  State<RegisterItemPage> createState() => _RegisterItemPageState();
}

class _RegisterItemPageState extends State<RegisterItemPage> {
  // GlobalKey untuk validasi form
  final _formKey = GlobalKey<FormState>();

  // Controller untuk menangkap input dari setiap field
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _limitController = TextEditingController();
  final _uomController = TextEditingController(); // Controller baru untuk UoM
  final _reminderLimitController = TextEditingController();
  
  // State untuk kontrol switch reminder
  bool _isReminderActive = false;

  @override
  void dispose() {
    // Memastikan semua controller dihapus dari memori saat page ditutup
    _codeController.dispose();
    _descController.dispose();
    _limitController.dispose();
    _uomController.dispose();
    _reminderLimitController.dispose();
    super.dispose();
  }

  /// Fungsi untuk mengosongkan kembali seluruh inputan di form
  void _clearForm() {
    _formKey.currentState?.reset();
    _codeController.clear();
    _descController.clear();
    _limitController.clear();
    _uomController.clear();
    _reminderLimitController.clear();
    setState(() {
      _isReminderActive = false;
    });
  }

  /// Fungsi untuk memproses penyimpanan data ke database SQLite
  Future<void> _submitData() async {
    // Validasi form sebelum proses simpan
    if (_formKey.currentState!.validate()) {
      try {
        final String code = _codeController.text.trim();

        // 1. VALIDASI DUPLIKASI: Cek apakah kode item sudah ada di database
        bool isDuplicate = await AppDb.instance.isItemCodeExists(code);

        if (isDuplicate) {
          if (!mounted) return;
          // Tampilkan snackbar jika kode sudah terdaftar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Item Code "$code" sudah terdaftar!'),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return; 
        }

        // 2. Persiapan data dalam bentuk Map untuk dimasukkan ke SQLite
        final Map<String, dynamic> row = {
          'code': code,
          'description': _descController.text,
          'unit': _uomController.text.trim(), // Data UoM yang baru ditambahkan
          'limit_value': double.tryParse(_limitController.text) ?? 0.0,
          'is_reminder': _isReminderActive ? 1 : 0,
          'reminder_limit': _isReminderActive
              ? (double.tryParse(_reminderLimitController.text) ?? 0.0)
              : 0.0,
        };

        // Eksekusi insert ke database
        await AppDb.instance.insertItem(row);

        if (!mounted) return;
        
        // Notifikasi sukses
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil menyimpan data ke database!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Reset form dan beri sinyal refresh ke halaman lain
        _clearForm();
        Future.delayed(Duration.zero, () {
          RefreshNotifier.triggerRefresh();
        });
      } catch (e) {
        // Handling error tak terduga
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
              Text(
                "Register New Item",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // Input Kode Item
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Item Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Input Deskripsi Item
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),

              // Baris untuk Limit Value dan UoM (Kotak kecil di sebelah kanan)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kolom Limit Value (Mengambil sisa ruang yang ada)
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _limitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Limit Value',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.summarize),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onChanged: (_) => _isReminderActive
                          ? _formKey.currentState!.validate()
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Kolom UoM (Kotak lebih kecil)
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _uomController,
                      decoration: const InputDecoration(
                        labelText: 'UoM',
                        hintText: 'Kg/Pcs',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Area pengaturan Reminder (Switch & Input)
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withOpacity(0.3),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Activate Reminder"),
                      value: _isReminderActive,
                      onChanged: (val) =>
                          setState(() => _isReminderActive = val),
                    ),
                    if (_isReminderActive)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _reminderLimitController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reminder Limit',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            double? limit = double.tryParse(_limitController.text);
                            double? reminder = double.tryParse(value);
                            if (limit != null &&
                                reminder != null &&
                                reminder > limit) {
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

              // Tombol Submit Data
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