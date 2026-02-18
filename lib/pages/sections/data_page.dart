import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';
import '../../data/session/refresh_notifier.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = true;

  final int _itemsPerPage = 8;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  // Expanded item → document details cache
  int? _expandedItemId;
  List<Map<String, dynamic>> _expandedDocs = [];
  bool _loadingDocs = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await AppDb.instance.getAllItems();
    if (!mounted) return;
    setState(() {
      _allData = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<Map<String, dynamic>> results = List.from(_allData);
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
      _currentPage = 1;
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

  Future<void> _toggleExpand(int itemId) async {
    if (_expandedItemId == itemId) {
      setState(() {
        _expandedItemId = null;
        _expandedDocs = [];
      });
      return;
    }
    setState(() {
      _loadingDocs = true;
      _expandedItemId = itemId;
    });
    final docs = await AppDb.instance.getDocumentDetailsForItem(itemId);
    if (!mounted) return;
    setState(() {
      _expandedDocs = docs;
      _loadingDocs = false;
    });
  }

  Future<void> _showEditDialog(Map<String, dynamic> docDetail, ColorScheme cs) async {
    final limitCtl = TextEditingController(
      text: (docDetail['doc_limit_value'] ?? 0).toString(),
    );
    final reminderCtl = TextEditingController(
      text: (docDetail['reminder_limit'] ?? 0).toString(),
    );
    bool isReminderActive = (docDetail['is_reminder'] ?? 0) == 1;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Edit — ${docDetail['doc_number']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: limitCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Limit Value',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.summarize),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Activate Reminder'),
                      value: isReminderActive,
                      onChanged: (val) => setDialogState(() => isReminderActive = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (isReminderActive) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: reminderCtl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reminder Limit',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notifications_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx, {
                      'limitValue': double.tryParse(limitCtl.text) ?? 0.0,
                      'isReminder': isReminderActive,
                      'reminderLimit': isReminderActive
                          ? (double.tryParse(reminderCtl.text) ?? 0.0)
                          : 0.0,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final docItemId = docDetail['doc_item_id'] as int;
      final itemId = docDetail['item_id'] as int;

      // Update document_items limit
      await AppDb.instance.updateDocumentItem(
        docItemId,
        limitValue: result['limitValue'] as double,
      );
      // Update item reminder
      await AppDb.instance.updateItem(itemId, {
        'is_reminder': result['isReminder'] == true ? 1 : 0,
        'reminder_limit': result['reminderLimit'] ?? 0.0,
      });

      // Refresh expanded docs
      final docs = await AppDb.instance.getDocumentDetailsForItem(itemId);
      if (!mounted) return;
      setState(() => _expandedDocs = docs);
      RefreshNotifier.triggerRefresh();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil diperbarui!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder(
      valueListenable: RefreshNotifier.refreshCounter,
      builder: (context, counter, child) {
        return FutureBuilder(
          future: AppDb.instance.getAllItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              _allData = snapshot.data!;
              Future.microtask(() {
                if (mounted) _applyFilter();
              });
            }

            final totalPages = (_filteredData.length / _itemsPerPage).ceil();

            return Scaffold(
              backgroundColor: cs.surfaceContainerLowest,
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchBar(cs),
                            const SizedBox(height: 16),
                            ..._getCurrentPageData().map((item) => _buildItemCard(item, cs)),
                            if (_filteredData.isEmpty) _buildEmptyState(cs),
                            if (_filteredData.isNotEmpty) _buildPagination(totalPages, cs),
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

  Widget _buildSearchBar(ColorScheme cs) {
    return SizedBox(
      width: 350,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _applyFilter(),
        decoration: InputDecoration(
          hintText: "Search item code or description...",
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
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

  Widget _buildItemCard(Map<String, dynamic> item, ColorScheme cs) {
    final itemId = item['id'] as int;
    final isExpanded = _expandedItemId == itemId;
    final code = item['code'] ?? '-';
    final desc = item['description'] ?? '-';
    final uom = item['uom'] ?? '-';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpanded
              ? cs.primary.withOpacity(0.5)
              : cs.outlineVariant.withOpacity(0.5),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                code[0].toUpperCase(),
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$desc  •  UoM: $uom', style: TextStyle(fontSize: 12, color: cs.outline)),
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: cs.primary,
              ),
              onPressed: () => _toggleExpand(itemId),
            ),
          ),

          if (isExpanded) ...[
            Divider(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
            if (_loadingDocs)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_expandedDocs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Item ini belum terdaftar di dokumen manapun.',
                  style: TextStyle(color: cs.outline),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    // Header row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: cs.primaryContainer.withOpacity(0.15),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Limit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Used', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Remaining', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text('Reminder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                          SizedBox(width: 48),
                        ],
                      ),
                    ),
                    ..._expandedDocs.map((doc) {
                      final limit = (doc['doc_limit_value'] as num?)?.toDouble() ?? 0.0;
                      final consumed = (doc['consumed'] as num?)?.toDouble() ?? 0.0;
                      final remaining = limit - consumed;
                      final isReminder = (doc['is_reminder'] ?? 0) == 1;
                      final reminderLimit = (doc['reminder_limit'] as num?)?.toDouble() ?? 0.0;
                      final hasUsage = consumed > 0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                doc['doc_number'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                limit.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 13),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                consumed.toStringAsFixed(1),
                                style: TextStyle(fontSize: 13, color: consumed > 0 ? cs.primary : cs.outline),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                remaining.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: remaining <= 0 ? cs.error : Colors.green,
                                  fontWeight: remaining <= 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: isReminder
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: cs.secondaryContainer.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          reminderLimit.toStringAsFixed(1),
                                          style: TextStyle(
                                            color: cs.onSecondaryContainer,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Text('-', style: TextStyle(color: cs.outline, fontSize: 13)),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: hasUsage ? cs.outline.withOpacity(0.3) : Colors.blueAccent,
                                ),
                                onPressed: hasUsage ? null : () => _showEditDialog(doc, cs),
                                tooltip: hasUsage ? 'Cannot edit — item already used' : 'Edit limit & reminder',
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ],
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
            "Showing ${(_currentPage - 1) * _itemsPerPage + 1} to "
            "${_currentPage * _itemsPerPage > _filteredData.length ? _filteredData.length : _currentPage * _itemsPerPage} "
            "of ${_filteredData.length} items",
            style: TextStyle(fontSize: 13, color: cs.outline),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              Text("Page $_currentPage of $totalPages", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
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
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text("No items found match your criteria."),
          ],
        ),
      ),
    );
  }
}
