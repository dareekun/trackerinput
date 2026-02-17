import 'package:flutter/material.dart';
import '../../data/db/app_db.dart';
import 'package:go_router/go_router.dart';
import '../../data/session/refresh_notifier.dart';

class DocumentListPage extends StatefulWidget {
  const DocumentListPage({super.key});

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  List<Map<String, dynamic>> _allDocs = [];
  List<Map<String, dynamic>> _filteredDocs = [];
  bool _isLoading = true;

  final int _itemsPerPage = 8;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  // Expanded document items
  int? _expandedDocId;
  List<Map<String, dynamic>> _expandedItems = [];
  bool _loadingItems = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await AppDb.instance.getAllDocumentsWithItemCount();
    if (!mounted) return;
    setState(() {
      _allDocs = data;
      _filteredDocs = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<Map<String, dynamic>> results = List.from(_allDocs);

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      results = results.where((doc) {
        final docNum = doc['doc_number'].toString().toLowerCase();
        return docNum.contains(query);
      }).toList();
    }

    setState(() {
      _filteredDocs = results;
      _currentPage = 1;
    });
  }

  List<Map<String, dynamic>> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredDocs.length) return [];
    return _filteredDocs.sublist(
      startIndex,
      endIndex > _filteredDocs.length ? _filteredDocs.length : endIndex,
    );
  }

  Future<void> _toggleExpand(int docId) async {
    if (_expandedDocId == docId) {
      setState(() {
        _expandedDocId = null;
        _expandedItems = [];
      });
      return;
    }

    setState(() {
      _loadingItems = true;
      _expandedDocId = docId;
    });

    final items = await AppDb.instance.getDocumentItems(docId);
    if (!mounted) return;
    setState(() {
      _expandedItems = items;
      _loadingItems = false;
    });
  }

  Future<void> _confirmDeleteDoc(int id, String docNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dokumen'),
        content: Text(
          'Apakah Anda yakin ingin menghapus dokumen "$docNumber" beserta semua item di dalamnya?',
        ),
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
      await AppDb.instance.deleteDocument(id);
      Future.delayed(Duration.zero, () {
        RefreshNotifier.triggerRefresh();
      });
      if (_expandedDocId == id) {
        _expandedDocId = null;
        _expandedItems = [];
      }
      _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dokumen berhasil dihapus'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmRemoveItem(int docItemId, String itemCode) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Item'),
        content: Text('Hapus item "$itemCode" dari dokumen ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDb.instance.deleteDocumentItem(docItemId);
      // Refresh the expanded items
      if (_expandedDocId != null) {
        final items = await AppDb.instance.getDocumentItems(_expandedDocId!);
        if (!mounted) return;
        setState(() => _expandedItems = items);
      }
      // Refresh doc list for updated item count
      _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item dihapus dari dokumen'),
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
          future: AppDb.instance.getAllDocumentsWithItemCount(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              _allDocs = snapshot.data!;
              Future.microtask(() {
                if (mounted) _applyFilter();
              });
            }

            final totalPages = (_filteredDocs.length / _itemsPerPage).ceil();

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
                            _buildDocList(cs),
                            if (_filteredDocs.isEmpty) _buildEmptyState(cs),
                            if (_filteredDocs.isNotEmpty)
                              _buildPagination(totalPages, cs),
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
          hintText: "Search document number...",
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

  Widget _buildDocList(ColorScheme cs) {
    final pageData = _getCurrentPageData();

    return Column(
      children: pageData.map((doc) {
        final docId = doc['id'] as int;
        final docNumber = doc['doc_number'] as String;
        final itemCount = doc['item_count'] as int? ?? 0;
        final createdAt = doc['created_at'] as String? ?? '-';
        final isExpanded = _expandedDocId == docId;

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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.description_outlined, color: cs.primary),
                ),
                title: Text(
                  docNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '$itemCount item(s)  •  Created: ${createdAt.split('T').first}',
                  style: TextStyle(color: cs.outline, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: cs.primary,
                      ),
                      onPressed: () => _toggleExpand(docId),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: cs.error,
                        size: 20,
                      ),
                      onPressed: () => _confirmDeleteDoc(docId, docNumber),
                    ),
                  ],
                ),
              ),
              // Expanded items section
              if (isExpanded) ...[
                Divider(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
                if (_loadingItems)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_expandedItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Belum ada item di dokumen ini.',
                      style: TextStyle(color: cs.outline),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          color: cs.primaryContainer.withOpacity(0.15),
                          child: const Row(
                            children: [
                              Expanded(
                                  flex: 2,
                                  child: Text('Code',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Expanded(
                                  flex: 3,
                                  child: Text('Description',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12))),
                              Expanded(
                                  flex: 2,
                                  child: Text('Limit',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                      textAlign: TextAlign.right)),
                              Expanded(
                                  flex: 1,
                                  child: Text('UoM',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12),
                                      textAlign: TextAlign.center)),
                              SizedBox(width: 48), // space for delete button
                            ],
                          ),
                        ),
                        ..._expandedItems.map((item) {
                          final limitValue = item['doc_limit_value'] ??
                              item['item_limit_value'] ??
                              0;
                          final uom =
                              item['doc_uom'] ?? item['item_uom'] ?? '-';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: cs.outlineVariant.withOpacity(0.2),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item['code'] ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item['description'] ?? '-',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    limitValue.toString(),
                                    style: const TextStyle(fontSize: 13),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    uom.toString(),
                                    style: const TextStyle(fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: IconButton(
                                    icon: Icon(Icons.remove_circle_outline,
                                        color: cs.error, size: 18),
                                    onPressed: () => _confirmRemoveItem(
                                      item['doc_item_id'] as int,
                                      item['code'] ?? '-',
                                    ),
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
      }).toList(),
    );
  }

  Widget _buildPagination(int totalPages, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Showing ${(_currentPage - 1) * _itemsPerPage + 1} to "
            "${_currentPage * _itemsPerPage > _filteredDocs.length ? _filteredDocs.length : _currentPage * _itemsPerPage} "
            "of ${_filteredDocs.length} documents",
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
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 16),
            const Text("No documents found."),
          ],
        ),
      ),
    );
  }
}
