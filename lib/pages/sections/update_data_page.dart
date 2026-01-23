import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';
import 'package:go_router/go_router.dart';

class UpdateDataPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const UpdateDataPage({super.key, required this.item});

  @override
  State<UpdateDataPage> createState() => _UpdateDataPageState();
}

class _UpdateDataPageState extends State<UpdateDataPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _limitController;
  late TextEditingController _reminderLimitController;
  late bool _isReminderActive;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.item['code']);
    _descController = TextEditingController(text: widget.item['description']);
    _limitController = TextEditingController(text: widget.item['limit_value'].toString());
    _isReminderActive = widget.item['is_reminder'] == 1;
    _reminderLimitController = TextEditingController(
      text: _isReminderActive ? widget.item['reminder_limit'].toString() : '',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descController.dispose();
    _limitController.dispose();
    _reminderLimitController.dispose();
    super.dispose();
  }

  Future<void> _updateData() async {
    if (_formKey.currentState!.validate()) {
      try {
        final Map<String, dynamic> updatedRow = {
          'code': _codeController.text, // Tetap dikirim namun nilainya tidak berubah
          'description': _descController.text,
          'limit_value': double.tryParse(_limitController.text) ?? 0.0,
          'is_reminder': _isReminderActive ? 1 : 0,
          'reminder_limit': _isReminderActive 
              ? (double.tryParse(_reminderLimitController.text) ?? 0.0) 
              : 0.0,
        };

        await AppDb.instance.updateItem(widget.item['id'], updatedRow);

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil diupdate!'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );

        context.pop(true); 
        
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Item Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INFO SECTION
              const Text(
                "Primary Information",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              // FIELD: ITEM CODE (READ ONLY)
              TextFormField(
                controller: _codeController,
                readOnly: true, // MENGUNCI FIELD
                decoration: InputDecoration(
                  labelText: 'Item Code',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20), // Ikon gembok sebagai indikator
                  filled: true,
                  fillColor: cs.surfaceContainerHigh, // Warna berbeda untuk menandakan read-only
                  border: const OutlineInputBorder(),
                  helperText: "Item code cannot be changed after registration.",
                ),
              ),
              const SizedBox(height: 16),

              // FIELD: DESCRIPTION (TAMBAHAN BARU)
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Item Description',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.description_outlined),
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "Configuration",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              // FIELD: LIMIT VALUE
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Limit Value',
                  prefixIcon: Icon(Icons.speed),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // REMINDER TOGGLE
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Activate Reminder"),
                      secondary: const Icon(Icons.notifications_active_outlined),
                      value: _isReminderActive,
                      onChanged: (val) => setState(() => _isReminderActive = val),
                    ),
                    if (_isReminderActive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: TextFormField(
                          controller: _reminderLimitController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reminder Threshold',
                            border: OutlineInputBorder(),
                            prefixText: 'Qty: ',
                          ),
                          validator: (v) {
                            if (_isReminderActive) {
                              if (v == null || v.isEmpty) {
                                return 'Required when reminder is active';
                              }
                              
                              // Ambil nilai dari kedua controller
                              final double? limitValue = double.tryParse(_limitController.text);
                              final double? reminderValue = double.tryParse(v);

                              if (limitValue != null && reminderValue != null) {
                                if (reminderValue > limitValue) {
                                  return 'Cannot exceed Limit Value ($limitValue)';
                                }
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // BUTTON UPDATE
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _updateData,
                  icon: const Icon(Icons.save_as),
                  label: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}