import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db/app_db.dart';
import '../../data/session/refresh_notifier.dart';

class RegisterDocPage extends StatefulWidget {
  const RegisterDocPage({super.key});

  @override
  State<RegisterDocPage> createState() => _RegisterDocPageState();
}

class _RegisterDocPageState extends State<RegisterDocPage> {
  // === Document ===
  final _docFormKey = GlobalKey<FormState>();
  final _docNumberCtl = TextEditingController();
  bool _docConfirmed = false; // Step 1 done (locally, NOT saved to DB yet)
  String? _currentDocNumber;
  DateTime _docDate = DateTime.now();

  // === Item Form (new item) ===
  final _itemFormKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _limitController = TextEditingController();
  final _uomController = TextEditingController();
  final _reminderLimitController = TextEditingController();
  bool _isReminderActive = false;

  // === Existing items (for searchable dropdown) ===
  List<Map<String, dynamic>> _allItems = [];
  Map<String, dynamic>? _selectedExistingItem;
  bool _useExistingItem = false;
  final _searchCtl = TextEditingController();
  List<Map<String, dynamic>> _filteredItems = [];
  final _existingLimitCtl = TextEditingController();
  final _existingUomCtl = TextEditingController();
  // Reminder for existing item
  bool _existingReminderActive = false;
  final _existingReminderLimitCtl = TextEditingController();

  // === Staged items (local list, NOT in DB yet) ===
  // Each entry: { 'isNew': bool, 'itemId': int? (existing), 'code', 'description',
  //   'limitValue', 'uom', 'isReminder', 'reminderLimit', 'newItemRow': Map? }
  List<Map<String, dynamic>> _stagedItems = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingItems();
  }

  @override
  void dispose() {
    _docNumberCtl.dispose();
    _codeController.dispose();
    _descController.dispose();
    _limitController.dispose();
    _uomController.dispose();
    _reminderLimitController.dispose();
    _searchCtl.dispose();
    _existingLimitCtl.dispose();
    _existingUomCtl.dispose();
    _existingReminderLimitCtl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingItems() async {
    final items = await AppDb.instance.getAllItems();
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _filteredItems = items;
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = _allItems.where((item) {
        final code = item['code'].toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        return code.contains(query.toLowerCase()) || desc.contains(query.toLowerCase());
      }).toList();
    });
  }

  // === STEP 1: Confirm document number (local only, no DB insert) ===
  Future<void> _submitDocument() async {
    if (!(_docFormKey.currentState?.validate() ?? false)) return;
    final docNum = _docNumberCtl.text.trim();

    try {
      final exists = await AppDb.instance.isDocNumberExists(docNum);
      if (exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "$docNum" sudah terdaftar!'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _docConfirmed = true;
        _currentDocNumber = docNum;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // === STEP 2: Add item to staged list (local only) ===
  Future<void> _addItemToDocument() async {
    if (!_docConfirmed) return;

    try {
      if (_useExistingItem) {
        // Use existing item from dropdown
        if (_selectedExistingItem == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pilih item terlebih dahulu!')),
          );
          return;
        }
        final itemId = _selectedExistingItem!['id'] as int;

        // Check duplicate in staged list
        if (_stagedItems.any((s) => s['itemId'] == itemId)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item ini sudah ada di daftar dokumen!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final limitText = _existingLimitCtl.text.trim();
        if (limitText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Limit Value wajib diisi!')),
          );
          return;
        }
        final docLimitValue = double.tryParse(limitText) ?? 0.0;
        final docUom = (_selectedExistingItem!['uom'] as String?) ?? '';

        // Validate reminder limit for existing items
        if (_existingReminderActive) {
          final reminderVal = double.tryParse(_existingReminderLimitCtl.text.trim()) ?? 0.0;
          if (_existingReminderLimitCtl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reminder Limit wajib diisi!')),
            );
            return;
          }
          if (reminderVal > docLimitValue) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reminder Limit tidak boleh melebihi Limit Value ($docLimitValue)!')),
            );
            return;
          }
        }

        setState(() {
          _stagedItems.add({
            'isNew': false,
            'itemId': itemId,
            'code': _selectedExistingItem!['code'],
            'description': _selectedExistingItem!['description'] ?? '',
            'limitValue': docLimitValue,
            'uom': docUom,
            'isReminder': _existingReminderActive,
            'reminderLimit': _existingReminderActive
                ? (double.tryParse(_existingReminderLimitCtl.text.trim()) ?? 0.0)
                : 0.0,
          });
        });
      } else {
        // Create new item (staged — will be inserted into DB on final save)
        if (!(_itemFormKey.currentState?.validate() ?? false)) return;
        final code = _codeController.text.trim();

        // Check duplicate code in DB
        final isDuplicate = await AppDb.instance.isItemCodeExists(code);
        if (isDuplicate) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item Code "$code" sudah terdaftar! Gunakan pilih item yang sudah ada.'),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Also check duplicate code in staged new items
        if (_stagedItems.any((s) => s['isNew'] == true && s['code'] == code)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item Code "$code" sudah ada di daftar!'),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final docLimitValue = double.tryParse(_limitController.text) ?? 0.0;
        final docUom = _uomController.text.trim();

        setState(() {
          _stagedItems.add({
            'isNew': true,
            'itemId': null,
            'code': code,
            'description': _descController.text,
            'limitValue': docLimitValue,
            'uom': docUom,
            'isReminder': _isReminderActive,
            'reminderLimit': _isReminderActive
                ? (double.tryParse(_reminderLimitController.text) ?? 0.0)
                : 0.0,
          });
        });
      }

      _clearItemForm();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item ditambahkan ke daftar!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeStagedItem(int index) {
    setState(() => _stagedItems.removeAt(index));
  }

  void _clearItemForm() {
    _itemFormKey.currentState?.reset();
    _codeController.clear();
    _descController.clear();
    _limitController.clear();
    _uomController.clear();
    _reminderLimitController.clear();
    _searchCtl.clear();
    _existingLimitCtl.clear();
    _existingUomCtl.clear();
    _existingReminderLimitCtl.clear();
    setState(() {
      _isReminderActive = false;
      _existingReminderActive = false;
      _selectedExistingItem = null;
      _filteredItems = _allItems;
    });
  }

  // === FINAL SAVE: Commit document + all items to DB ===
  Future<void> _saveDocument() async {
    if (_stagedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Dokumen harus memiliki minimal 1 item sebelum bisa disimpan!',
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Insert document with date
      final docId = await AppDb.instance.insertDocument(
        _currentDocNumber!,
        date: DateFormat('yyyy-MM-dd').format(_docDate),
      );

      // 2. Insert each staged item
      for (final staged in _stagedItems) {
        int itemId;

        if (staged['isNew'] == true) {
          // Create new item in items table
          final row = {
            'code': staged['code'],
            'description': staged['description'],
            'uom': staged['uom'],
            'limit_value': staged['limitValue'],
            'is_reminder': staged['isReminder'] == true ? 1 : 0,
            'reminder_limit': staged['reminderLimit'] ?? 0.0,
          };
          itemId = await AppDb.instance.insertItem(row);
        } else {
          itemId = staged['itemId'] as int;
          // Update reminder on existing item if changed
          if (staged['isReminder'] == true) {
            await AppDb.instance.updateItem(itemId, {
              'is_reminder': 1,
              'reminder_limit': staged['reminderLimit'] ?? 0.0,
            });
          }
        }

        // Link item to document
        await AppDb.instance.insertDocumentItem(
          docId,
          itemId,
          limitValue: staged['limitValue'] as double?,
          uom: staged['uom'] as String?,
        );
      }

      if (!mounted) return;

      RefreshNotifier.triggerRefresh();
      await _loadExistingItems();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document "$_currentDocNumber" berhasil disimpan dengan ${_stagedItems.length} item!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset for next document
      _clearItemForm();
      _docNumberCtl.clear();
      setState(() {
        _docConfirmed = false;
        _currentDocNumber = null;
        _docDate = DateTime.now();
        _stagedItems = [];
        _useExistingItem = false;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _resetAll() {
    _clearItemForm();
    _docNumberCtl.clear();
    setState(() {
      _docConfirmed = false;
      _currentDocNumber = null;
      _docDate = DateTime.now();
      _stagedItems = [];
      _useExistingItem = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Register Document",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // ======== STEP 1: DOCUMENT NUMBER ========
            if (!_docConfirmed) _buildDocumentForm(cs),
            if (_docConfirmed) ...[
              _buildActiveDocHeader(cs),
              const SizedBox(height: 24),

              // ======== STEP 2: ADD ITEMS ========
              _buildItemSection(cs),
              const SizedBox(height: 24),

              // ======== ITEM LIST IN DOCUMENT ========
              _buildDocItemsList(cs),
              const SizedBox(height: 24),

              // ======== SAVE DOCUMENT TO DB ========
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveDocument,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? "Saving..." : "SAVE DOCUMENT"),
                ),
              ),
              const SizedBox(height: 12),
              // ======== DISCARD / RESET ========
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _resetAll,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Discard & Start Over"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============ DOCUMENT FORM ============
  Widget _buildDocumentForm(ColorScheme cs) {
    return Form(
      key: _docFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _docNumberCtl,
            decoration: const InputDecoration(
              labelText: 'Document Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description_outlined),
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _docDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _docDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Document Date',
                prefixIcon: Icon(Icons.calendar_month),
                border: OutlineInputBorder(),
              ),
              child: Text(DateFormat('EEEE, dd MMMM yyyy').format(_docDate)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _submitDocument,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text("CREATE DOCUMENT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ ACTIVE DOC HEADER ============
  Widget _buildActiveDocHeader(ColorScheme cs) {
    return Card(
      elevation: 0,
      color: cs.primaryContainer.withOpacity(0.3),
      child: ListTile(
        leading: Icon(Icons.folder_open, color: cs.primary),
        title: Text(
          'Document: $_currentDocNumber',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${_stagedItems.length} item(s) staged  •  Date: ${DateFormat('dd MMM yyyy').format(_docDate)}'),
      ),
    );
  }

  // ============ ITEM SECTION (toggle existing / new) ============
  Widget _buildItemSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Add Item to Document",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        // Toggle between existing item or new item
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Existing Item'), icon: Icon(Icons.search)),
            ButtonSegment(value: false, label: Text('New Item'), icon: Icon(Icons.add)),
          ],
          selected: {_useExistingItem},
          onSelectionChanged: (v) {
            setState(() {
              _useExistingItem = v.first;
              _selectedExistingItem = null;
              _searchCtl.clear();
              _filteredItems = _allItems;
            });
          },
        ),
        const SizedBox(height: 16),

        if (_useExistingItem) _buildExistingItemPicker(cs),
        if (!_useExistingItem) _buildNewItemForm(cs),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _addItemToDocument,
            icon: const Icon(Icons.add_box),
            label: const Text("ADD ITEM TO DOCUMENT"),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ============ SEARCHABLE DROPDOWN FOR EXISTING ITEMS ============
  Widget _buildExistingItemPicker(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtl,
          decoration: InputDecoration(
            labelText: 'Search item...',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchCtl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtl.clear();
                      _filterItems('');
                    },
                  )
                : null,
          ),
          onChanged: _filterItems,
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _filteredItems.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No items found', style: TextStyle(color: Colors.grey)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _filteredItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    final isSelected = _selectedExistingItem?['id'] == item['id'];
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor: cs.primaryContainer.withOpacity(0.3),
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? cs.primary : cs.outline,
                        size: 20,
                      ),
                      title: Text(
                        item['code'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(item['description'] ?? '-'),
                      trailing: Text(
                        'Limit: ${item['limit_value'] ?? 0}',
                        style: TextStyle(color: cs.outline, fontSize: 12),
                      ),
                      onTap: () => setState(() {
                        _selectedExistingItem = item;
                        _existingUomCtl.text = item['uom'] ?? '';
                        _existingLimitCtl.clear();
                      }),
                    );
                  },
                ),
        ),
        if (_selectedExistingItem != null) ...[
          const SizedBox(height: 8),
          Chip(
            label: Text(
              '${_selectedExistingItem!['code']} — ${_selectedExistingItem!['description'] ?? 'No desc'}',
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => setState(() {
              _selectedExistingItem = null;
              _existingLimitCtl.clear();
              _existingUomCtl.clear();
            }),
          ),
          const SizedBox(height: 16),
          // Limit & UoM fields for this document
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _existingLimitCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Limit Value (for this document)',
                    hintText: 'Default: ${_selectedExistingItem!['limit_value'] ?? 0}',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.summarize),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _existingUomCtl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'UoM',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Reminder toggle for existing item
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Activate Reminder"),
                  value: _existingReminderActive,
                  onChanged: (val) => setState(() => _existingReminderActive = val),
                ),
                if (_existingReminderActive)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      controller: _existingReminderLimitCtl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reminder Limit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============ NEW ITEM FORM ============
  Widget _buildNewItemForm(ColorScheme cs) {
    return Form(
      key: _itemFormKey,
      child: Column(
        children: [
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      ? _itemFormKey.currentState!.validate()
                      : null,
                ),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Activate Reminder"),
                  value: _isReminderActive,
                  onChanged: (val) => setState(() => _isReminderActive = val),
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
                        if (value == null || value.isEmpty) return 'Required';
                        double? limit = double.tryParse(_limitController.text);
                        double? reminder = double.tryParse(value);
                        if (limit != null && reminder != null && reminder > limit) {
                          return 'Cannot exceed Limit Value ($limit)';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ DOCUMENT ITEMS LIST (staged) ============
  Widget _buildDocItemsList(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Items in Document",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (_stagedItems.isEmpty)
          Card(
            elevation: 0,
            color: cs.surfaceContainerHighest.withOpacity(0.2),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Belum ada item di dokumen ini.'),
            ),
          )
        else
          ...List.generate(_stagedItems.length, (i) {
            final item = _stagedItems[i];
            final hasReminder = item['isReminder'] == true;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      item['code'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (item['isNew'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('NEW', style: TextStyle(fontSize: 10, color: cs.tertiary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    if (hasReminder) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.notifications_active, size: 16, color: Colors.orange.shade700),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${item['description'] ?? '-'}  •  Limit: ${item['limitValue'] ?? 0}  •  UoM: ${item['uom'] ?? '-'}'
                  '${hasReminder ? '  •  Reminder: ${item['reminderLimit']}' : ''}',
                ),
                trailing: IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: cs.error),
                  onPressed: () => _removeStagedItem(i),
                ),
              ),
            );
          }),
      ],
    );
  }
}