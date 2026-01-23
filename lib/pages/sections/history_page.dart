import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db/app_db.dart'; 
import 'package:go_router/go_router.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;

  // Pagination & Search
  final int _itemsPerPage = 5;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  // Sorting
  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    // Mengambil data transaksi yang sudah di-JOIN dengan tabel items
    final data = await AppDb.instance.getAllTransactions();
    setState(() {
      _allTransactions = data;
      _filteredTransactions = data;
      _isLoading = false;
      _applyFilterAndSort();
    });
  }

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
      _currentPage = 1;
    });
  }

  void _sort<T>(Comparable<T> Function(Map<String, dynamic> d) getField, int columnIndex, bool ascending) {
    _filteredTransactions.sort((a, b) {
      final aValue = getField(a);
      final bValue = getField(b);
      return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
    });
  }

  List<Map<String, dynamic>> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredTransactions.length) return [];
    return _filteredTransactions.sublist(
      startIndex, 
      endIndex > _filteredTransactions.length ? _filteredTransactions.length : endIndex
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                      _buildSearchBar(cs),
                      const SizedBox(height: 16),
                      // AREA TABEL
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
                                  child: DataTable(
                                    sortColumnIndex: _sortColumnIndex,
                                    sortAscending: _isAscending,
                                    headingRowColor: WidgetStateProperty.all(cs.primaryContainer.withOpacity(0.2)),
                                    columns: _buildColumns(),
                                    rows: _getCurrentPageData().asMap().entries.map((entry) {
                                      return _buildRow(entry.value, entry.key, context, cs);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            if (_filteredTransactions.isEmpty) _buildEmptyState(cs),
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
  }

  List<DataColumn> _buildColumns() {
    const textStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return [
      const DataColumn(label: Text('NO', style: textStyle)),
      DataColumn(
        label: const Text('ITEM CODE', style: textStyle),
        onSort: (idx, asc) => _sort((d) => d['item_code'], idx, asc),
      ),
      // KOLOM BARU: DESCRIPTION
      DataColumn(
        label: const Text('DESCRIPTION', style: textStyle),
        onSort: (idx, asc) => _sort((d) => d['description'] ?? "", idx, asc),
      ),
      DataColumn(
        label: const Text('VALUE', style: textStyle),
        numeric: true,
        onSort: (idx, asc) => _sort((d) => d['value'], idx, asc),
      ),
      DataColumn(
        label: const Text('DATE', style: textStyle),
        onSort: (idx, asc) => _sort((d) => d['date'], idx, asc),
      ),
      const DataColumn(label: Text('ACTION', style: textStyle)),
    ];
  }

  DataRow _buildRow(Map<String, dynamic> tx, int index, BuildContext context, ColorScheme cs) {
    // Logika nomor urut kontinu
    final int displayIndex = ((_currentPage - 1) * _itemsPerPage) + index + 1;

    return DataRow(cells: [
      DataCell(Text("$displayIndex")),
      DataCell(Text(tx['item_code'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
      // DATA BARU: DESCRIPTION
      DataCell(Text(tx['description'] ?? '-', style: TextStyle(color: cs.onSurfaceVariant))),
      DataCell(Text(tx['value'].toString(), style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.parse(tx['date'])))),
      DataCell(
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
          onPressed: () => _confirmDelete(tx['id']),
        ),
      ),
    ]);
  }

  // --- WIDGET PENDUKUNG ---

  Widget _buildSearchBar(ColorScheme cs) {
    return SizedBox(
      width: 400,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _applyFilterAndSort(),
        decoration: InputDecoration(
          hintText: "Search item code or description...",
          prefixIcon: const Icon(Icons.history, size: 20),
          filled: true,
          fillColor: cs.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalPages, ColorScheme cs) {
    if (_filteredTransactions.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${_currentPage * _itemsPerPage > _filteredTransactions.length ? _filteredTransactions.length : _currentPage * _itemsPerPage} of ${_filteredTransactions.length} entries"),
          Row(
            children: [
              IconButton(onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null, icon: const Icon(Icons.chevron_left)),
              Text("$_currentPage / $totalPages", style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null, icon: const Icon(Icons.chevron_right)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, //
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          const Text("No records found."),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')), //
          FilledButton(onPressed: () => context.pop(true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await AppDb.instance.deleteTransaction(id);
      _fetchTransactions();
    }
  }
}