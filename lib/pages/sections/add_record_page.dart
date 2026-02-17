import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db/app_db.dart'; // Sesuaikan path database Anda
import '../../data/session/refresh_notifier.dart';

class AddRecordPage extends StatefulWidget {
  const AddRecordPage({super.key});

  @override
  State<AddRecordPage> createState() => _AddRecordPageState();
}

class _AddRecordPageState extends State<AddRecordPage> {
  final _formKey = GlobalKey<FormState>();

  // Controller & State untuk inputan user
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Data Item untuk menampung daftar dari database
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  Map<String, dynamic>? _selectedItem;
  bool _isLoading = true;

  // Document selection
  List<Map<String, dynamic>> _availableDocs = [];
  Map<String, dynamic>? _selectedDoc;
  double _consumedQuota = 0.0;
  bool _loadingDocs = false;

  @override
  void initState() {
    super.initState();
    // Initial load pertama kali halaman dibuka
    _loadItems();
  }

  /// Fungsi untuk mengambil daftar item terdaftar dari database SQLite
  Future<void> _loadItems() async {
    final items = await AppDb.instance.getAllItems();
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _filteredItems = items;
      _isLoading = false;
    });
  }

  /// Fungsi untuk menyaring daftar item berdasarkan input pencarian user
  void _filterItems(String query) {
    setState(() {
      _filteredItems = _allItems
          .where(
            (item) =>
                item['code'].toString().toLowerCase().contains(
                      query.toLowerCase(),
                    ) ||
                (item['description'] ?? "").toString().toLowerCase().contains(
                      query.toLowerCase(),
                    ),
          )
          .toList();
    });
  }

  /// Load documents that contain the selected item
  Future<void> _loadDocumentsForItem(int itemId) async {
    setState(() {
      _loadingDocs = true;
      _selectedDoc = null;
      _consumedQuota = 0.0;
      _availableDocs = [];
    });
    final docs = await AppDb.instance.getDocumentsForItem(itemId);
    if (!mounted) return;
    setState(() {
      _availableDocs = docs;
      _loadingDocs = false;
    });
  }

  /// Load consumed quota when a document is selected
  Future<void> _loadConsumedQuota() async {
    if (_selectedItem == null || _selectedDoc == null) return;
    final consumed = await AppDb.instance.getConsumedQuota(
      _selectedItem!['id'] as int,
      _selectedDoc!['id'] as int,
    );
    if (!mounted) return;
    setState(() => _consumedQuota = consumed);
  }

  /// Handle item selection
  void _onItemSelected(Map<String, dynamic> item) {
    setState(() {
      _selectedItem = item;
      _selectedDoc = null;
      _consumedQuota = 0.0;
      _availableDocs = [];
    });
    _loadDocumentsForItem(item['id'] as int);
  }

  /// Handle document selection
  void _onDocSelected(Map<String, dynamic>? doc) {
    setState(() => _selectedDoc = doc);
    _loadConsumedQuota();
  }

  /// Fungsi untuk menampilkan kalender dan memilih tanggal transaksi
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Fungsi untuk memvalidasi dan menyimpan transaksi baru ke database
  Future<void> _saveData() async {
    // Validasi apakah item sudah dipilih
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an item first!")),
      );
      return;
    }

    // Validasi apakah dokumen sudah dipilih
    if (_selectedDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a document number!"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validasi form input value
    if (_formKey.currentState!.validate()) {
      try {
        final inputValue = double.tryParse(_valueController.text) ?? 0.0;

        // Quota check
        final docLimit = (_selectedDoc!['doc_limit_value'] as num?)?.toDouble() ?? 0.0;
        final remaining = docLimit - _consumedQuota;

        if (docLimit > 0 && inputValue > remaining) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Quota exceeded! Limit: ${docLimit.toStringAsFixed(1)}, '
                'Used: ${_consumedQuota.toStringAsFixed(1)}, '
                'Remaining: ${remaining.toStringAsFixed(1)}, '
                'Input: ${inputValue.toStringAsFixed(1)}',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        final newData = {
          'item_id': _selectedItem!['id'],
          'item_code': _selectedItem!['code'],
          'document_id': _selectedDoc!['id'],
          'value': inputValue,
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'created_at': DateTime.now().toIso8601String(),
        };

        // Simpan transaksi ke database
        await AppDb.instance.insertTransaction(newData);
        
        // Memicu refresh global agar halaman lain (Dashboard, History) terupdate
        Future.delayed(Duration.zero, () {
          RefreshNotifier.triggerRefresh();
        });

        if (!mounted) return;

        // Reset form setelah berhasil simpan
        setState(() {
          _valueController.clear();
          _selectedItem = null;
          _selectedDoc = null;
          _availableDocs = [];
          _consumedQuota = 0.0;
          _searchController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data successfully added!"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ValueListenableBuilder mendengarkan sinyal dari RefreshNotifier
    return ValueListenableBuilder(
      valueListenable: RefreshNotifier.refreshCounter,
      builder: (context, counter, child) {
        
        // FutureBuilder mengambil data item terbaru setiap kali ada sinyal refresh
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: AppDb.instance.getAllItems(),
          builder: (context, snapshot) {
            
            // Jika data berhasil diambil, update list internal
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              _allItems = snapshot.data!;
              
              // Logika agar hasil pencarian tidak hilang saat refresh otomatis terjadi
              _filteredItems = _searchController.text.isEmpty 
                  ? _allItems 
                  : _allItems.where((item) => 
                      item['code'].toString().toLowerCase().contains(_searchController.text.toLowerCase())
                    ).toList();
            }

            return Scaffold(
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Select Item",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Memanggil widget selector item
                            _buildItemSelector(cs),

                            const SizedBox(height: 24),

                            // Document dropdown (only when item selected)
                            if (_selectedItem != null) ...[
                              Text(
                                "Select Document",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDocumentSelector(cs),
                              const SizedBox(height: 24),
                            ],

                            // Input untuk nominal/nilai transaksi
                            TextFormField(
                              controller: _valueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Input Value",
                                prefixIcon: Icon(Icons.calculate_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v!.isEmpty ? "Value required" : null,
                            ),

                            const SizedBox(height: 16),

                            // Picker untuk tanggal transaksi
                            InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: "Transaction Date",
                                  prefixIcon: Icon(Icons.calendar_month),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  DateFormat(
                                    'EEEE, dd MMMM yyyy',
                                  ).format(_selectedDate),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Tombol untuk eksekusi simpan
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: _saveData,
                                icon: const Icon(Icons.check_circle),
                                label: const Text(
                                  "SAVE TRANSACTION",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  /// Widget untuk membangun area pemilihan item yang dilengkapi fitur pencarian
  Widget _buildItemSelector(ColorScheme cs) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Field pencarian di dalam selector
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterItems,
              decoration: InputDecoration(
                hintText: "Search code...",
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Daftar item yang bisa dipilih
          Expanded(
            child: ListView.builder(
              itemCount: _filteredItems.length,
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isSelected = _selectedItem?['id'] == item['id'];

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: cs.primaryContainer.withOpacity(0.3),
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    child: Text(
                      item['code'][0],
                      style: TextStyle(
                        color: isSelected ? Colors.white : cs.onSurface,
                      ),
                    ),
                  ),
                  title: Text(
                    item['code'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(item['description'] ?? "No description"),
                  onTap: () => _onItemSelected(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Widget for document selection dropdown with quota info
  Widget _buildDocumentSelector(ColorScheme cs) {
    if (_loadingDocs) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_availableDocs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: cs.errorContainer.withOpacity(0.3),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Item ini belum terdaftar di dokumen manapun. Daftarkan terlebih dahulu via Register Doc.',
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          value: _selectedDoc?['id'] as int?,
          decoration: const InputDecoration(
            labelText: 'Document Number',
            prefixIcon: Icon(Icons.description_outlined),
            border: OutlineInputBorder(),
          ),
          items: _availableDocs.map((doc) {
            return DropdownMenuItem<int>(
              value: doc['id'] as int,
              child: Text(doc['doc_number'] as String),
            );
          }).toList(),
          onChanged: (docId) {
            if (docId == null) return;
            final doc = _availableDocs.firstWhere((d) => d['id'] == docId);
            _onDocSelected(doc);
          },
          validator: (_) => _selectedDoc == null ? 'Select a document' : null,
        ),

        // Quota info
        if (_selectedDoc != null) ...[
          const SizedBox(height: 12),
          _buildQuotaInfo(cs),
        ],
      ],
    );
  }

  Widget _buildQuotaInfo(ColorScheme cs) {
    final docLimit = (_selectedDoc!['doc_limit_value'] as num?)?.toDouble() ?? 0.0;
    final remaining = docLimit - _consumedQuota;
    final uom = (_selectedDoc!['doc_uom'] as String?) ?? '';
    final percentage = docLimit > 0 ? (_consumedQuota / docLimit).clamp(0.0, 1.0) : 0.0;

    Color barColor;
    if (percentage >= 1.0) {
      barColor = cs.error;
    } else if (percentage >= 0.8) {
      barColor = Colors.orange;
    } else {
      barColor = cs.primary;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: cs.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quota Usage',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: cs.onSurface,
                ),
              ),
              Text(
                '${_consumedQuota.toStringAsFixed(1)} / ${docLimit.toStringAsFixed(1)} $uom',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: cs.outlineVariant.withOpacity(0.3),
              color: barColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Remaining: ${remaining.toStringAsFixed(1)} $uom',
            style: TextStyle(
              fontSize: 12,
              color: remaining <= 0 ? cs.error : cs.outline,
              fontWeight: remaining <= 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}