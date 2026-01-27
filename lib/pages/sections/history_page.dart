import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db/app_db.dart'; 
import 'package:go_router/go_router.dart';
import '../../data/services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;

  final int _itemsPerPage = 5;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  // --- LOGIKA DATA ---
  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
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

  // --- UI UTAMA ---
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
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(cs), // Baris tunggal yang Anda minta
                  const SizedBox(height: 24),
                  _buildTableSection(constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width), cs: cs, totalPages: totalPages),
                ],
              ),
            ),
          ),
    );
  }

  // --- FUNGSI TAMBAHAN (WIDGETS) ---

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => _applyFilterAndSort(),
      decoration: InputDecoration(
        hintText: "Search item code or description...",
        prefixIcon: const Icon(Icons.history, size: 20),
        filled: true,
        fillColor: cs.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
      ),
    );
  }

  Widget _buildTableSection({required BoxConstraints constraints, required ColorScheme cs, required int totalPages}) {
    return Container(
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
                  rows: _getCurrentPageData().asMap().entries.map((entry) => _buildRow(entry.value, entry.key, context, cs)).toList(),
                ),
              ),
            ),
          ),
          if (_filteredTransactions.isEmpty) _buildEmptyState(cs),
          _buildPagination(totalPages, cs),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return [
      const DataColumn(label: Text('NO', style: style)),
      DataColumn(label: const Text('ITEM CODE', style: style), onSort: (idx, asc) => _sort((d) => d['item_code'], idx, asc)),
      DataColumn(label: const Text('DESCRIPTION', style: style), onSort: (idx, asc) => _sort((d) => d['description'] ?? "", idx, asc)),
      DataColumn(label: const Text('VALUE', style: style), numeric: true, onSort: (idx, asc) => _sort((d) => d['value'], idx, asc)),
      DataColumn(label: const Text('DATE', style: style), onSort: (idx, asc) => _sort((d) => d['date'], idx, asc)),
      const DataColumn(label: Text('ACTION', style: style)),
    ];
  }

  DataRow _buildRow(Map<String, dynamic> tx, int index, BuildContext context, ColorScheme cs) {
    final int displayIndex = ((_currentPage - 1) * _itemsPerPage) + index + 1;
    return DataRow(cells: [
      DataCell(Text("$displayIndex")),
      DataCell(Text(tx['item_code'].toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(Text(tx['description'] ?? '-', style: TextStyle(color: cs.onSurfaceVariant))),
      DataCell(Text(tx['value'].toString(), style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.parse(tx['date'])))),
      DataCell(IconButton(icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20), onPressed: () => _confirmDelete(tx['id']))),
    ]);
  }

  Widget _buildPagination(int totalPages, ColorScheme cs) {
    if (_filteredTransactions.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${_currentPage * _itemsPerPage > _filteredTransactions.length ? _filteredTransactions.length : _currentPage * _itemsPerPage} of ${_filteredTransactions.length}"),
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
      child: Column(children: [
        Icon(Icons.inventory_2_outlined, size: 64, color: cs.outlineVariant),
        const SizedBox(height: 16),
        const Text("No records found."),
      ]),
    );
  }

  // --- LOGIKA EXPORT & DELETE ---
  Future<void> _handleExport() async {
  setState(() => _isLoading = true);
  try {
    await HistoryService.exportTransactionHistory(
      data: _filteredTransactions,
      allDataForSummary: _allTransactions,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Excel Exported Successfully"), backgroundColor: Colors.green),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Export Failed"), backgroundColor: Colors.red),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _confirmDelete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
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