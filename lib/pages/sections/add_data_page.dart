import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db/app_db.dart'; // Sesuaikan path database Anda
import '../../data/session/refresh_notifier.dart';

class AddDataPage extends StatefulWidget {
  const AddDataPage({super.key});

  @override
  State<AddDataPage> createState() => _AddDataPageState();
}

class _AddDataPageState extends State<AddDataPage> {
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

    // Validasi form input value
    if (_formKey.currentState!.validate()) {
      try {
        final newData = {
          'item_id': _selectedItem!['id'],
          'item_code': _selectedItem!['code'],
          'value': double.tryParse(_valueController.text) ?? 0.0,
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
                  : Padding(
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

                            const Spacer(),

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
                  onTap: () => setState(() => _selectedItem = item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}