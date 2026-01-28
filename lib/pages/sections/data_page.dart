import 'package:flutter/material.dart';
import '../../data/db/app_db.dart'; // Sesuaikan path ini
import 'package:go_router/go_router.dart';
import '../../data/session/refresh_notifier.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  // --- STATE DATA ---
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = true;

  // --- PAGINATION & SEARCH ---
  final int _itemsPerPage = 8;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  // --- SORTING ---
  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await AppDb.instance.getAllItems();
    setState(() {
      _allData = data;
      _filteredData = data;
      _isLoading = false;
      _applyFilterAndSort(); // Sinkronisasi pencarian jika ada
    });
  }

  void _applyFilterAndSort() {
    List<Map<String, dynamic>> results = List.from(_allData);

    // Fitur Pencarian: Berdasarkan Code dan Description
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      results = results.where((item) {
        final code = item['code'].toString().toLowerCase();
        final desc = (item['description'] ?? "").toString().toLowerCase();
        return code.contains(query) || desc.contains(query);
      }).toList();
    }

    setState(() {
      _filteredData = results;
      _currentPage = 1; // Reset ke halaman pertama saat mencari data
    });
  }

  void _sort<T>(
    Comparable<T> Function(Map<String, dynamic> d) getField,
    int columnIndex,
    bool ascending,
  ) {
    _filteredData.sort((a, b) {
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

  List<Map<String, dynamic>> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredData.length) return [];
    return _filteredData.sublist(
      startIndex,
      endIndex > _filteredData.length ? _filteredData.length : endIndex,
    );
  }

  Future<void> _confirmDelete(int id, String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: Text('Apakah Anda yakin ingin menghapus item "$code"?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDb.instance.deleteItem(id);
      Future.delayed(Duration.zero, () {
        RefreshNotifier.triggerRefresh();
      });
      _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil dihapus'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  // 1. Bungkus dengan ValueListenableBuilder untuk memantau sinyal perubahan data
  return ValueListenableBuilder(
    valueListenable: RefreshNotifier.refreshCounter,
    builder: (context, counter, child) {
      
      // 2. Gunakan FutureBuilder agar data terbaru selalu ditarik saat sinyal diterima
      return FutureBuilder(
        future: AppDb.instance.getAllItems(), // Ganti dengan fungsi ambil data item Anda
        builder: (context, snapshot) {
          
          // Sinkronisasi data lokal ketika database selesai memberikan data terbaru
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            _allData = snapshot.data!;
            
            // Jalankan filter agar hasil pencarian tetap akurat setelah refresh
            Future.microtask(() {
              if (mounted) _applyFilterAndSort();
            });
          }

          final totalPages = (_filteredData.length / _itemsPerPage).ceil();

          return Scaffold(
            backgroundColor: cs.surfaceContainerLowest,
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchBar(cs),
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
                                    if (_filteredData.isEmpty) _buildEmptyState(cs),
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

  Widget _buildSearchBar(ColorScheme cs) {
    return SizedBox(
      width: 350,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _applyFilterAndSort(),
        decoration: InputDecoration(
          hintText: "Search item code or description...",
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilterAndSort();
                  },
                )
              : null,
          filled: true,
          fillColor: cs.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outlineVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages, ColorScheme cs) {
    if (_filteredData.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${_currentPage * _itemsPerPage > _filteredData.length ? _filteredData.length : _currentPage * _itemsPerPage} of ${_filteredData.length} entries",
            style: TextStyle(fontSize: 13, color: cs.outline),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Text(
                "Page $_currentPage of $totalPages",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
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

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Perbaikan MainState
        children: [
          Icon(Icons.search_off, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          const Text("No items found match your criteria."),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    const textStyle = TextStyle(
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
      fontSize: 12,
    );
    return [
      DataColumn(
        label: const Text('Item Code', style: textStyle),
        onSort: (idx, asc) => _sort((d) => d['code'], idx, asc),
      ),
      DataColumn(
        label: const Text('Item Description', style: textStyle),
        onSort: (idx, asc) => _sort((d) => d['description'] ?? "", idx, asc),
      ),
      DataColumn(
        label: const Text('Limit Value', style: textStyle),
        numeric: true,
        onSort: (idx, asc) => _sort((d) => d['limit_value'] ?? 0.0, idx, asc),
      ),
      DataColumn(
        label: const Text('Reminder Value', style: textStyle),
        numeric: true,
        onSort: (idx, asc) =>
            _sort((d) => d['reminder_limit'] ?? 0.0, idx, asc),
      ),
      const DataColumn(label: Text('Action', style: textStyle)),
    ];
  }

  DataRow _buildRow(
    Map<String, dynamic> item,
    int index,
    BuildContext context,
    ColorScheme cs,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            item['code'].toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(item['description'] ?? '-')),
        DataCell(Text(item['limit_value']?.toString() ?? '0')),
        DataCell(
          item['is_reminder'] == 1
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item['reminder_limit'].toString(),
                    style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const Text("-"),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.blueAccent,
                  size: 20,
                ),
                onPressed: () async {
                  final result = await context.push('/update', extra: item);
                  if (result == true) _fetchData();
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _confirmDelete(item['id'], item['code']),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
