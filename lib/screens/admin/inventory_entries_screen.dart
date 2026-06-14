import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS LOCALES
// ══════════════════════════════════════════════════════════════════════════════

class _EntryModel {
  final String id;
  final DateTime createdAt;
  final String? warehouseName;
  final String? supplierName;
  final String? notes;
  final double totalAmount;
  final String documentType;
  final String? documentNumber;
  final DateTime? documentDate;
  final String? purchaseOrderId;
  final int itemCount;

  const _EntryModel({
    required this.id,
    required this.createdAt,
    this.warehouseName,
    this.supplierName,
    this.notes,
    required this.totalAmount,
    required this.documentType,
    this.documentNumber,
    this.documentDate,
    this.purchaseOrderId,
    required this.itemCount,
  });

  factory _EntryModel.fromMap(Map<String, dynamic> m) {
    final wh = m['warehouses'] as Map<String, dynamic>?;
    final sup = m['suppliers'] as Map<String, dynamic>?;
    final items = m['inventory_entry_items'] as List? ?? [];
    return _EntryModel(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      warehouseName: wh?['name'] as String?,
      supplierName: sup?['name'] as String?,
      notes: m['notes'] as String?,
      totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
      documentType: m['document_type'] as String? ?? 'NINGUNO',
      documentNumber: m['document_number'] as String?,
      documentDate:
          m['document_date'] != null
              ? DateTime.tryParse(m['document_date'] as String)
              : null,
      purchaseOrderId: m['purchase_order_id'] as String?,
      itemCount: items.length,
    );
  }
}

class _EntryItemDetail {
  final String productName;
  final String variantAttrs;
  final double quantity;
  final double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;

  const _EntryItemDetail({
    required this.productName,
    required this.variantAttrs,
    required this.quantity,
    required this.unitCost,
    required this.batchNumber,
    this.expiryDate,
  });

  double get subtotal => quantity * unitCost;
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class InventoryEntriesScreen extends StatefulWidget {
  const InventoryEntriesScreen({super.key});

  @override
  State<InventoryEntriesScreen> createState() => _InventoryEntriesScreenState();
}

class _InventoryEntriesScreenState extends State<InventoryEntriesScreen> {
  final _supabase = Supabase.instance.client;

  List<_EntryModel> _allEntries = [];
  List<_EntryModel> _filtered = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _searchText = '';
  DateTimeRange? _dateRange;
  String _filterWarehouse = 'Todos';
  List<String> _warehouses = ['Todos'];

  static const int _pageSize = 20;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _supabase
          .from('inventory_entries')
          .select('''
            id, created_at, notes, total_amount,
            document_type, document_number, document_date, purchase_order_id,
            warehouses(name),
            suppliers(name),
            inventory_entry_items(id)
          ''')
          .order('created_at', ascending: false)
          .limit(500);

      final entries =
          (resp as List)
              .map(
                (e) => _EntryModel.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList();

      final whs = {
        'Todos',
        ...entries.map((e) => e.warehouseName ?? 'Sin almacén'),
      };

      if (mounted) {
        setState(() {
          _allEntries = entries;
          _warehouses = whs.toList();
          _loading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _applyFilters() {
    var result =
        _allEntries.where((e) {
          final matchSearch =
              _searchText.isEmpty ||
              (e.supplierName ?? '').toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ||
              (e.documentNumber ?? '').toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ||
              (e.notes ?? '').toLowerCase().contains(_searchText.toLowerCase());

          final matchWh =
              _filterWarehouse == 'Todos' ||
              (e.warehouseName ?? 'Sin almacén') == _filterWarehouse;

          final matchDate =
              _dateRange == null ||
              (!e.createdAt.isBefore(_dateRange!.start) &&
                  !e.createdAt.isAfter(
                    _dateRange!.end.add(
                      const Duration(days: 1),
                    ), // +1 day para incluir todo el día seleccionado
                  ));

          return matchSearch && matchWh && matchDate;
        }).toList();

    setState(() {
      _filtered = result;
      _currentPage = 0;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

  Future<List<_EntryItemDetail>> _loadItems(String entryId) async {
    final resp = await _supabase
        .from('inventory_entry_items')
        .select('''
          quantity, unit_cost, batch_number, expiry_date,
          products(name),
          product_variants(attributes)
        ''')
        .eq('entry_id', entryId);
    return (resp as List).map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variant = r['product_variants'] as Map<String, dynamic>?;
      final attrs = Map<String, dynamic>.from(
        (variant?['attributes'] as Map?) ?? {},
      );
      final attrsText = attrs.values.map((e) => '$e').join(' · ');
      return _EntryItemDetail(
        productName: prod?['name'] as String? ?? '—',
        variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
        quantity: (r['quantity'] as num).toDouble(),
        unitCost: (r['unit_cost'] as num).toDouble(),
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
        expiryDate:
            r['expiry_date'] != null
                ? DateTime.tryParse(r['expiry_date'] as String)
                : null,
      );
    }).toList();
  }

  void _showDetail(_EntryModel entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _EntryDetailSheet(
            entry: entry,
            loadItems: () => _loadItems(entry.id),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages =
        _filtered.isEmpty ? 1 : (_filtered.length / _pageSize).ceil();
    final safePage = _currentPage >= totalPages ? 0 : _currentPage;
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    final pageItems = _filtered.sublist(start, end);

    final totalAmount = _filtered.fold<double>(0, (s, e) => s + e.totalAmount);

    return AdminLayout(
      title: 'Historial de Entradas',
      showBackButton: true,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Resumen ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _SummaryChip(
                      label: 'Entradas',
                      value: '${_filtered.length}',
                      icon: Icons.move_to_inbox_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _SummaryChip(
                      label: 'Total invertido',
                      value: 'S/ ${totalAmount.toStringAsFixed(2)}',
                      icon: Icons.payments_rounded,
                      color: AppColors.teal,
                    ),
                  ],
                ),
              ),
            ),

            // ── Filtros ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SearchField(
                            controller: _searchCtrl,
                            hint: 'Buscar proveedor, comprobante...',
                            onChanged: (v) {
                              _searchText = v;
                              _applyFilters();
                            },
                            onClear: () {
                              _searchCtrl.clear();
                              _searchText = '';
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DateRangeButton(
                          dateRange: _dateRange,
                          onTap: _pickDateRange,
                          onClear: () {
                            setState(() => _dateRange = null);
                            _applyFilters();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            _warehouses.map((w) {
                              final sel = _filterWarehouse == w;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(w),
                                  selected: sel,
                                  onSelected: (_) {
                                    setState(() => _filterWarehouse = w);
                                    _applyFilters();
                                  },
                                  selectedColor: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                    color:
                                        sel
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Contador ──────────────────────────────────────────────────
            if (!_loading && _filtered.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                  child: Text(
                    'Mostrando ${start + 1}–$end de ${_filtered.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // ── Lista ─────────────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.inbox_outlined,
                  message:
                      _allEntries.isEmpty
                          ? 'No hay entradas registradas'
                          : 'Sin resultados para los filtros aplicados',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList.separated(
                  itemCount: pageItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder:
                      (_, i) => _EntryCard(
                        entry: pageItems[i],
                        onTap: () => _showDetail(pageItems[i]),
                      ),
                ),
              ),

            // ── Paginación ────────────────────────────────────────────────
            if (!_loading && totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: _SimplePaginator(
                    currentPage: safePage,
                    totalPages: totalPages,
                    onChanged: (p) => setState(() => _currentPage = p),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const InventoryEntryFormScreen()),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva entrada'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY CARD
// ══════════════════════════════════════════════════════════════════════════════

class _EntryCard extends StatelessWidget {
  final _EntryModel entry;
  final VoidCallback onTap;
  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final hasDoc =
        entry.documentType != 'NINGUNO' && entry.documentNumber != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.move_to_inbox_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.supplierName ?? 'Sin proveedor',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          fmt.format(entry.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${entry.itemCount} producto${entry.itemCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Pill(
                    icon: Icons.warehouse_rounded,
                    label: entry.warehouseName ?? 'Sin almacén',
                  ),
                  if (hasDoc)
                    _Pill(
                      icon: Icons.receipt_long_rounded,
                      label: '${entry.documentType} ${entry.documentNumber}',
                      color: AppColors.teal,
                    ),
                  if (entry.purchaseOrderId != null)
                    _Pill(
                      icon: Icons.link_rounded,
                      label: 'Orden de compra',
                      color: Colors.purple.shade400,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _EntryDetailSheet extends StatefulWidget {
  final _EntryModel entry;
  final Future<List<_EntryItemDetail>> Function() loadItems;

  const _EntryDetailSheet({required this.entry, required this.loadItems});

  @override
  State<_EntryDetailSheet> createState() => _EntryDetailSheetState();
}

class _EntryDetailSheetState extends State<_EntryDetailSheet> {
  List<_EntryItemDetail>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.loadItems().then((items) {
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final entry = widget.entry;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder:
          (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.supplierName ?? 'Sin proveedor',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              fmt.format(entry.createdAt.toLocal()),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            entry.warehouseName ?? 'Sin almacén',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Items
                Expanded(
                  child:
                      _loading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                          : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.all(20),
                            itemCount: _items!.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final item = _items![i];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            '${item.variantAttrs} · Lote: ${item.batchNumber}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          if (item.expiryDate != null)
                                            Text(
                                              'Vence: ${DateFormat('dd/MM/yyyy').format(item.expiryDate!)}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item.quantity.toStringAsFixed(0)} uds.',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'S/ ${item.unitCost.toStringAsFixed(2)} c/u',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          'S/ ${item.subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      suffixIcon:
          controller.text.isNotEmpty
              ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: onClear,
              )
              : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: AppColors.surface,
    ),
  );
}

class _DateRangeButton extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateRangeButton({
    required this.dateRange,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = dateRange != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color:
              hasDate
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              hasDate
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 18,
              color: hasDate ? AppColors.primary : AppColors.textSecondary,
            ),
            if (hasDate) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimplePaginator extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onChanged;
  const _SimplePaginator({
    required this.currentPage,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: currentPage > 0 ? () => onChanged(currentPage - 1) : null,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text(
        'Pág. ${currentPage + 1} / $totalPages',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      IconButton(
        onPressed:
            currentPage < totalPages - 1
                ? () => onChanged(currentPage + 1)
                : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 34,
            color: AppColors.textSecondary.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
