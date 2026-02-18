import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db/app_db.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/history_service.dart';
import '../../data/session/refresh_notifier.dart'; // Penting untuk update dashboard

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;

  final int _itemsPerPage = 8;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions(); // Ambil data saat pertama kali halaman dibuka
  }

  // --- LOGIKA DATA ---

  /// Mengambil semua data transaksi dari database lokal
  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    final data = await AppDb.instance.getAllTransactions();
    setState(() {
      _allTransactions = data;
      _filteredTransactions = data;
      _isLoading = false;
      _applyFilterAndSort(); // Terapkan filter setelah data berhasil diambil
    });
  }

  /// Memfilter data berdasarkan input pencarian pada kode item atau deskripsi
  void _applyFilterAndSort() {
    List<Map<String, dynamic>> results = List.from(_allTransactions);
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      results = results.where((tx) {
        final code = tx['item_code'].toString().toLowerCase();
        final desc = (tx['description'] ?? "").toString().toLowerCase();
        return code.contains(query) || desc.contains(query);
      }).toList();
    }
    setState(() {
      _filteredTransactions = results;
      _currentPage = 1; // Reset ke halaman pertama setiap kali filter berubah
    });
  }

  /// Logika pengurutan (sorting) data pada tabel
  void _sort<T>(
    Comparable<T> Function(Map<String, dynamic> d) getField,
    int columnIndex,
    bool ascending,
  ) {
    _filteredTransactions.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending
          ? Comparable.compare(aValue, bValue)
          : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
    });
  }

  /// Mengambil potongan data (sublist) yang hanya ditampilkan pada halaman saat ini
  List<Map<String, dynamic>> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredTransactions.length) return [];
    return _filteredTransactions.sublist(
      startIndex,
      endIndex > _filteredTransactions.length
          ? _filteredTransactions.length
          : endIndex,
    );
  }

  // --- UI UTAMA ---
  @override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  // 1. Bungkus dengan ValueListenableBuilder untuk memantau sinyal refresh
  return ValueListenableBuilder(
    valueListenable: RefreshNotifier.refreshCounter,
    builder: (context, counter, child) {
      
      // 2. Jalankan FutureBuilder untuk mengambil data terbaru dari DB
      return FutureBuilder(
        future: AppDb.instance.getAllTransactions(),
        builder: (context, snapshot) {
          
          // Logika pembaruan data lokal saat snapshot berubah
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            _allTransactions = snapshot.data!;
            
            // Kita gunakan Future.microtask agar tidak terjadi bentrok setState saat render
            Future.microtask(() {
              if (mounted) _applyFilterAndSort();
            });
          }

          final totalPages = (_filteredTransactions.length / _itemsPerPage).ceil();

          return Scaffold(
            backgroundColor: cs.surfaceContainerLowest,
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchTransactions,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // AREA SEARCH
                              _buildTopBar(cs),
                              const SizedBox(height: 16),

                              // TABEL DATA
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cs.outlineVariant.withOpacity(0.5),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: constraints.maxWidth - 48,
                                          ),
                                          child: DataTable(
                                            sortColumnIndex: _sortColumnIndex,
                                            sortAscending: _isAscending,
                                            headingRowColor: WidgetStateProperty.all(
                                              cs.primaryContainer.withOpacity(0.2),
                                            ),
                                            columns: _buildColumns(),
                                            rows: _getCurrentPageData()
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              return _buildRow(
                                                entry.value,
                                                entry.key,
                                                context,
                                                cs,
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),

                                    if (_filteredTransactions.isEmpty)
                                      _buildEmptyState(cs),

                                    // NAVIGASI PAGINATION
                                    _buildPagination(totalPages, cs),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          );
        },
      );
    },
  );
}

  // --- WIDGET BUILDERS ---

  /// Membuat baris atas yang berisi kolom pencarian dan tombol export
  Widget _buildTopBar(ColorScheme cs) {
    return Row(
      children: [
        Expanded(child: _buildSearchBar(cs)),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: _filteredTransactions.isEmpty ? null : _handleExport,
          icon: const Icon(Icons.file_download),
          label: const Text("Export Excel"),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// Membuat input field pencarian
  Widget _buildSearchBar(ColorScheme cs) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => _applyFilterAndSort(),
      decoration: InputDecoration(
        hintText: "Search item code...",
        prefixIcon: const Icon(Icons.history, size: 20),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),
    );
  }

  /// Menentukan nama-nama kolom tabel
  List<DataColumn> _buildColumns() {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return [
      DataColumn(
        label: const Text('Item Code', style: style),
        onSort: (idx, asc) => _sort((d) => d['item_code'], idx, asc),
      ),
      DataColumn(
        label: const Text('Description', style: style),
        onSort: (idx, asc) => _sort((d) => d['description'] ?? "", idx, asc),
      ),
      DataColumn(
        label: const Text('Document', style: style),
        onSort: (idx, asc) => _sort((d) => d['doc_number'] ?? "", idx, asc),
      ),
      DataColumn(
        label: const Text('Value', style: style),
        numeric: true,
        onSort: (idx, asc) => _sort((d) => d['value'], idx, asc),
      ),
      DataColumn(
        label: const Text('Date', style: style),
        onSort: (idx, asc) => _sort((d) => d['date'], idx, asc),
      ),
      const DataColumn(
        label: Text('Actions', style: style),
      ),
    ];
  }

  /// Membangun baris data dan tombol aksi (Edit & Delete)
  DataRow _buildRow(
    Map<String, dynamic> tx,
    int index,
    BuildContext context,
    ColorScheme cs,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            tx['item_code'].toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataCell(
          Text(
            tx['description'] ?? '-',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        DataCell(
          Text(
            tx['doc_number'] ?? '-',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        DataCell(
          Text(
            tx['value'].toString(),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(DateFormat('dd MMM yyyy').format(DateTime.parse(tx['date']))),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
                onPressed: () => _handleEdit(tx),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(tx['id']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Kontrol navigasi halaman (pagination)
  Widget _buildPagination(int totalPages, ColorScheme cs) {
    if (_filteredTransactions.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${_currentPage * _itemsPerPage > _filteredTransactions.length ? _filteredTransactions.length : _currentPage * _itemsPerPage} of ${_filteredTransactions.length}",
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                "$_currentPage / $totalPages",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tampilan jika data kosong
  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          const Text("No records found."),
        ],
      ),
    );
  }

  // --- LOGIKA AKSI (EDIT, EXPORT, DELETE) ---

  /// Menangani proses ekspor data ke Excel
  Future<void> _handleExport() async {
    setState(() => _isLoading = true);
    try {
      await HistoryService.exportTransactionHistory(
        data: _filteredTransactions,
        allDataForSummary: _allTransactions,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Excel Exported Successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Export Failed"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Memunculkan dialog untuk mengedit nilai (value) dan tanggal transaksi
  Future<void> _handleEdit(Map<String, dynamic> tx) async {
    // Inisialisasi controller dengan nilai lama
    final TextEditingController editValueCtl = TextEditingController(
      text: tx['value'].toString(),
    );

    // Simpan tanggal lama sebagai nilai awal
    DateTime selectedDate = DateTime.parse(tx['date']);

    final bool? updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // Digunakan agar UI di dalam dialog bisa update (setState)
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Edit Record: ${tx['item_code']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Input untuk Nilai (Value)
                TextField(
                  controller: editValueCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Value",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 16),

                // Input untuk Tanggal (Date Picker)
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2090),
                    );
                    if (picked != null && picked != selectedDate) {
                      // Gunakan setDialogState untuk merefresh tampilan tanggal di dalam dialog
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Date",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final newValue = double.tryParse(editValueCtl.text);
                  if (newValue != null) {
                    // Update ke Database (Nilai dan Tanggal)
                    // Pastikan format tanggal sesuai ISO (yyyy-MM-dd)
                    final dateStr = selectedDate.toIso8601String().split(
                      'T',
                    )[0];

                    await AppDb.instance.updateTransaction(
                      id: tx['id'],
                      value: newValue,
                      date: dateStr,
                    );

                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );

    if (updated == true) {
      _fetchTransactions(); // Refresh tabel history
      Future.delayed(Duration.zero, () {
        RefreshNotifier.triggerRefresh();
      });
    }
  }

  /// Konfirmasi sebelum menghapus data permanen
  Future<void> _confirmDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDb.instance.deleteTransaction(id);
      _fetchTransactions(); // Refresh tabel
      Future.delayed(Duration.zero, () {
        RefreshNotifier.triggerRefresh();
      });
    }
  }
}
