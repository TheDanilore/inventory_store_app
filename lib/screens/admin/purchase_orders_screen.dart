import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS
// ══════════════════════════════════════════════════════════════════════════════

class _POModel {
  final String id;
  final DateTime createdAt;
  final String? supplierId;
  final String supplierName;
  final String? warehouseName;
  final String status;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final double discountAmount;
  final double taxAmount;
  final String documentType;
  final String? documentNumber;
  final String? notes;
  final int itemCount;

  const _POModel({
    required this.id,
    required this.createdAt,
    this.supplierId,
    required this.supplierName,
    this.warehouseName,
    required this.status,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amountPaid,
    this.dueDate,
    required this.discountAmount,
    required this.taxAmount,
    required this.documentType,
    this.documentNumber,
    this.notes,
    required this.itemCount,
  });

  factory _POModel.fromMap(Map<String, dynamic> m) {
    final sup = m['suppliers'] as Map<String, dynamic>?;
    final wh = m['warehouses'] as Map<String, dynamic>?;
    final items = m['purchase_order_items'] as List? ?? [];
    return _POModel(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      supplierId: m['supplier_id'] as String?,
      supplierName:
          m['supplier_name'] as String? ??
          sup?['name'] as String? ??
          'Sin proveedor',
      warehouseName: wh?['name'] as String?,
      status: m['status'] as String? ?? 'PENDING',
      totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: m['payment_method'] as String? ?? 'EFECTIVO',
      paymentStatus: m['payment_status'] as String? ?? 'PAID',
      amountPaid: (m['amount_paid'] as num?)?.toDouble() ?? 0,
      dueDate:
          m['due_date'] != null
              ? DateTime.tryParse(m['due_date'] as String)
              : null,
      discountAmount: (m['discount_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (m['tax_amount'] as num?)?.toDouble() ?? 0,
      documentType: m['document_type'] as String? ?? 'NINGUNO',
      documentNumber: m['document_number'] as String?,
      notes: m['notes'] as String?,
      itemCount: items.length,
    );
  }

  double get pending => totalAmount - amountPaid;
  bool get isFullyPaid => paymentStatus == 'PAID';
}

class _POItemModel {
  final String? productName;
  final String variantAttrs;
  final String? sku;
  final double quantityOrdered;
  final double quantityReceived;
  final double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;

  const _POItemModel({
    this.productName,
    required this.variantAttrs,
    this.sku,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
    required this.batchNumber,
    this.expiryDate,
  });

  double get subtotal => quantityOrdered * unitCost;
  bool get fullyReceived => quantityReceived >= quantityOrdered;
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _supabase = Supabase.instance.client;

  List<_POModel> _all = [];
  List<_POModel> _filtered = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _searchText = '';
  String _filterStatus = 'Todos';
  DateTimeRange? _dateRange;

  static const int _pageSize = 20;
  int _currentPage = 0;

  static const _statusLabels = {
    'Todos': 'Todos',
    'PENDING': 'Pendiente',
    'SENT': 'Enviado',
    'PARTIAL': 'Parcial',
    'RECEIVED': 'Recibido',
    'CANCELLED': 'Cancelado',
  };

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
          .from('purchase_orders')
          .select('''
            id, created_at, supplier_id, supplier_name,
            status, total_amount, payment_method, payment_status,
            amount_paid, due_date, discount_amount, tax_amount,
            document_type, document_number, notes,
            suppliers(name),
            warehouses(name),
            purchase_order_items(id)
          ''')
          .order('created_at', ascending: false)
          .limit(500);

      final orders =
          (resp as List)
              .map((e) => _POModel.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();

      if (mounted) {
        setState(() {
          _all = orders;
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
        _all.where((po) {
          final matchSearch =
              _searchText.isEmpty ||
              po.supplierName.toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ||
              (po.documentNumber ?? '').toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ||
              (po.notes ?? '').toLowerCase().contains(
                _searchText.toLowerCase(),
              );

          final matchStatus =
              _filterStatus == 'Todos' || po.status == _filterStatus;

          final matchDate =
              _dateRange == null ||
              (!po.createdAt.isBefore(_dateRange!.start) &&
                  !po.createdAt.isAfter(
                    _dateRange!.end.add(const Duration(days: 1)),
                  ));

          return matchSearch && matchStatus && matchDate;
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      initialEntryMode: DatePickerEntryMode.input,
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

  Future<List<_POItemModel>> _loadItems(String poId) async {
    final resp = await _supabase
        .from('purchase_order_items')
        .select('''
          quantity_ordered, quantity_received, unit_cost,
          batch_number, expiry_date,
          products(name),
          product_variants(attributes, sku)
        ''')
        .eq('purchase_order_id', poId);

    return (resp as List).map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variant = r['product_variants'] as Map<String, dynamic>?;
      final attrs = Map<String, dynamic>.from(
        (variant?['attributes'] as Map?) ?? {},
      );
      final attrsText = attrs.values.map((e) => '$e').join(' · ');
      return _POItemModel(
        productName: prod?['name'] as String?,
        variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
        sku: variant?['sku'] as String?,
        quantityOrdered: (r['quantity_ordered'] as num).toDouble(),
        quantityReceived: (r['quantity_received'] as num?)?.toDouble() ?? 0,
        unitCost: (r['unit_cost'] as num).toDouble(),
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
        expiryDate:
            r['expiry_date'] != null
                ? DateTime.tryParse(r['expiry_date'] as String)
                : null,
      );
    }).toList();
  }

  void _showDetail(_POModel po) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _PODetailSheet(
            po: po,
            loadItems: () => _loadItems(po.id),
            onReceive: () async {
              final items = await _loadItems(po.id);
              if (!mounted) return;
              final entryItems =
                  items
                      .map(
                        (i) => EntryItemUI(
                          product: _dummyProduct(i.productName ?? '—'),
                          variant: _dummyVariant(i.variantAttrs),
                          quantity: i.quantityOrdered - i.quantityReceived,
                          unitCost: i.unitCost,
                          batchNumber: i.batchNumber,
                          expiryDate: i.expiryDate,
                        ),
                      )
                      .where((e) => e.quantity > 0)
                      .toList();

              if (!mounted) return;
              Navigator.pop(context);
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => InventoryEntryFormScreen(
                        purchaseOrderId: po.id,
                        prefillSupplierId: po.supplierId,
                        prefillSupplierName: po.supplierName,
                        prefillItems: entryItems,
                      ),
                ),
              );
              if (result == true) _load();
            },
            onUpdateStatus: (status) async {
              await _supabase
                  .from('purchase_orders')
                  .update({
                    'status': status,
                    'updated_at': DateTime.now().toIso8601String(),
                  })
                  .eq('id', po.id);
              if (mounted) {
                Navigator.pop(context);
                _load();
              }
            },
          ),
    );
  }

  // Helpers para pre-llenar InventoryEntryScreen desde una PO
  // El screen sólo necesita los IDs para la lógica de guardado;
  // los modelos completos se cargan internamente.
  static ProductModel _dummyProduct(String name) => ProductModel(
    id: '',
    name: name,
    unitCost: 0,
    salePrice: 0,
    isActive: true,
    stockControl: true,
    usesBatches: false,
    productType: 'good',
  );

  static ProductVariantModel _dummyVariant(String label) => ProductVariantModel(
    id: '',
    productId: '',
    attributes: {'Variante': label},
    isActive: true,
    reorderPoint: 0,
    unitCost: 0,
  );

  @override
  Widget build(BuildContext context) {
    final totalPages =
        _filtered.isEmpty ? 1 : (_filtered.length / _pageSize).ceil();
    final safePage = _currentPage >= totalPages ? 0 : _currentPage;
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    final pageItems = _filtered.sublist(start, end);

    final totalAmount = _filtered.fold<double>(
      0,
      (s, po) => s + po.totalAmount,
    );
    final pendingCount = _filtered.where((po) => po.status == 'PENDING').length;

    return AdminLayout(
      title: 'Órdenes de Compra',
      showBackButton: true,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Resumen ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _SummaryTile(
                      label: 'Órdenes',
                      value: '${_filtered.length}',
                      icon: Icons.shopping_cart_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      label: 'Total',
                      value: 'S/ ${totalAmount.toStringAsFixed(2)}',
                      icon: Icons.payments_rounded,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      label: 'Pendientes',
                      value: '$pendingCount',
                      icon: Icons.pending_actions_rounded,
                      color:
                          pendingCount > 0
                              ? AppColors.warning
                              : AppColors.success,
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
                            hint: 'Buscar proveedor, documento...',
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
                            _statusLabels.entries.map((e) {
                              final sel = _filterStatus == e.key;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(e.value),
                                  selected: sel,
                                  onSelected: (_) {
                                    setState(() => _filterStatus = e.key);
                                    _applyFilters();
                                  },
                                  selectedColor: _statusColor(
                                    e.key,
                                  ).withValues(alpha: 0.15),
                                  checkmarkColor: _statusColor(e.key),
                                  labelStyle: TextStyle(
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                    color:
                                        sel
                                            ? _statusColor(e.key)
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
                  icon: Icons.shopping_cart_outlined,
                  message:
                      _all.isEmpty
                          ? 'No hay órdenes de compra registradas'
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
                      (_, i) => _POCard(
                        po: pageItems[i],
                        onTap: () => _showDetail(pageItems[i]),
                      ),
                ),
              ),

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
        onPressed: () => _showCreateSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva orden'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _POCreateSheet(supabase: _supabase, onSaved: _load),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PO CARD
// ══════════════════════════════════════════════════════════════════════════════

class _POCard extends StatelessWidget {
  final _POModel po;
  final VoidCallback onTap;
  const _POCard({required this.po, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final statusColor = _statusColor(po.status);
    final statusLabel = _statusLabel(po.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          po.supplierName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          fmt.format(po.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S/ ${po.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.primary,
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
                    label: po.warehouseName ?? 'Sin almacén',
                  ),
                  _Pill(
                    icon: Icons.inventory_2_rounded,
                    label:
                        '${po.itemCount} producto${po.itemCount != 1 ? 's' : ''}',
                  ),
                  if (po.paymentStatus != 'PAID')
                    _Pill(
                      icon: Icons.money_off_rounded,
                      label: 'Pendiente S/ ${po.pending.toStringAsFixed(2)}',
                      color: AppColors.warning,
                    ),
                  if (po.dueDate != null && po.paymentStatus != 'PAID')
                    _Pill(
                      icon: Icons.event_rounded,
                      label: 'Vence ${fmt.format(po.dueDate!.toLocal())}',
                      color:
                          po.dueDate!.isBefore(DateTime.now())
                              ? AppColors.danger
                              : AppColors.textSecondary,
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
// PO DETAIL SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _PODetailSheet extends StatefulWidget {
  final _POModel po;
  final Future<List<_POItemModel>> Function() loadItems;
  final VoidCallback onReceive;
  final Future<void> Function(String status) onUpdateStatus;

  const _PODetailSheet({
    required this.po,
    required this.loadItems,
    required this.onReceive,
    required this.onUpdateStatus,
  });

  @override
  State<_PODetailSheet> createState() => _PODetailSheetState();
}

class _PODetailSheetState extends State<_PODetailSheet> {
  List<_POItemModel>? _items;
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
    final po = widget.po;
    final fmt = DateFormat('dd/MM/yyyy');
    final canReceive =
        po.status == 'PENDING' || po.status == 'SENT' || po.status == 'PARTIAL';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  po.supplierName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  fmt.format(po.createdAt.toLocal()),
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
                                'S/ ${po.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: AppColors.primary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    po.status,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _statusLabel(po.status),
                                  style: TextStyle(
                                    color: _statusColor(po.status),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
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
                          if (po.warehouseName != null)
                            _Pill(
                              icon: Icons.warehouse_rounded,
                              label: po.warehouseName!,
                            ),
                          _Pill(
                            icon: Icons.payments_rounded,
                            label: po.paymentMethod,
                          ),
                          _Pill(
                            icon:
                                po.isFullyPaid
                                    ? Icons.check_circle_rounded
                                    : Icons.pending_rounded,
                            label:
                                po.isFullyPaid
                                    ? 'Pagado'
                                    : 'Deuda: S/ ${po.pending.toStringAsFixed(2)}',
                            color:
                                po.isFullyPaid
                                    ? AppColors.success
                                    : AppColors.warning,
                          ),
                          if (po.documentType != 'NINGUNO' &&
                              po.documentNumber != null)
                            _Pill(
                              icon: Icons.receipt_long_rounded,
                              label: '${po.documentType} ${po.documentNumber}',
                              color: AppColors.teal,
                            ),
                        ],
                      ),
                      if (canReceive) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onReceive,
                            icon: const Icon(Icons.move_to_inbox_rounded),
                            label: const Text('Recibir mercadería'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (po.status != 'CANCELLED' &&
                          po.status != 'RECEIVED') ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: const Text('¿Cancelar orden?'),
                                      content: const Text(
                                        'Esta acción no se puede deshacer.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('No'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.danger,
                                          ),
                                          child: const Text(
                                            'Cancelar orden',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                              if (confirm == true) {
                                await widget.onUpdateStatus('CANCELLED');
                              }
                            },
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: AppColors.danger,
                            ),
                            label: const Text(
                              'Cancelar orden',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
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
                            padding: const EdgeInsets.all(16),
                            itemCount: _items!.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final item = _items![i];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      item.fullyReceived
                                          ? Border.all(
                                            color: AppColors.success.withValues(
                                              alpha: 0.3,
                                            ),
                                          )
                                          : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName ?? '—',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            item.variantAttrs,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          if (item.sku != null)
                                            Text(
                                              'SKU: ${item.sku}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textMuted,
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
                                          '${item.quantityReceived.toStringAsFixed(0)} / ${item.quantityOrdered.toStringAsFixed(0)} uds.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color:
                                                item.fullyReceived
                                                    ? AppColors.success
                                                    : AppColors.warning,
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
// PO CREATE SHEET — formulario básico para crear una orden de compra
// ══════════════════════════════════════════════════════════════════════════════

class _POCreateSheet extends StatefulWidget {
  final SupabaseClient supabase;
  final VoidCallback onSaved;
  const _POCreateSheet({required this.supabase, required this.onSaved});

  @override
  State<_POCreateSheet> createState() => _POCreateSheetState();
}

class _POCreateSheetState extends State<_POCreateSheet> {
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;
  bool _saving = false;

  String? _supplierId;
  String? _warehouseId;
  String _paymentMethod = 'EFECTIVO';
  String _paymentStatus = 'PAID';
  final String _documentType = 'NINGUNO';
  final _notesCtrl = TextEditingController();
  final _docNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _docNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      widget.supabase
          .from('suppliers')
          .select('id, name')
          .eq('is_active', true)
          .order('name'),
      widget.supabase
          .from('warehouses')
          .select('id, name')
          .eq('is_active', true),
    ]);
    if (mounted) {
      setState(() {
        _suppliers = List<Map<String, dynamic>>.from(results[0] as List);
        _warehouses = List<Map<String, dynamic>>.from(results[1] as List);
        if (_warehouses.isNotEmpty) _warehouseId = _warehouses.first['id'];
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = widget.supabase.auth.currentUser;
      String? profileId;
      if (user != null) {
        final p =
            await widget.supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', user.id)
                .maybeSingle();
        profileId = p?['id'] as String?;
      }

      final supplierName =
          _supplierId != null
              ? _suppliers.firstWhere(
                        (s) => s['id'] == _supplierId,
                        orElse: () => {},
                      )['name']
                      as String? ??
                  ''
              : '';

      await widget.supabase.from('purchase_orders').insert({
        'supplier_id': _supplierId,
        'supplier_name': supplierName,
        'warehouse_id': _warehouseId,
        'payment_method': _paymentMethod,
        'payment_status': _paymentStatus,
        'document_type': _documentType,
        'document_number':
            _docNumberCtrl.text.trim().isEmpty
                ? null
                : _docNumberCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'created_by': profileId,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child:
            _loading
                ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Nueva Orden de Compra',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _supplierId,
                        decoration: _dec(
                          'Proveedor',
                          icon: Icons.business_rounded,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Sin proveedor'),
                          ),
                          ..._suppliers.map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text(s['name'] as String),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _warehouseId,
                        decoration: _dec(
                          'Almacén destino',
                          icon: Icons.warehouse_rounded,
                        ),
                        items:
                            _warehouses
                                .map(
                                  (w) => DropdownMenuItem(
                                    value: w['id'] as String,
                                    child: Text(w['name'] as String),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _warehouseId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _paymentMethod,
                              decoration: _dec(
                                'Pago',
                                icon: Icons.payments_rounded,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'EFECTIVO',
                                  child: Text('Efectivo'),
                                ),
                                DropdownMenuItem(
                                  value: 'TRANSFERENCIA',
                                  child: Text('Transferencia'),
                                ),
                                DropdownMenuItem(
                                  value: 'CREDITO',
                                  child: Text('Crédito'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _paymentMethod = v;
                                    if (v == 'CREDITO') {
                                      _paymentStatus = 'PENDING';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _paymentStatus,
                              decoration: _dec(
                                'Estado pago',
                                icon: Icons.check_circle_outline_rounded,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PAID',
                                  child: Text('Pagado'),
                                ),
                                DropdownMenuItem(
                                  value: 'PENDING',
                                  child: Text('Pendiente'),
                                ),
                                DropdownMenuItem(
                                  value: 'PARTIAL',
                                  child: Text('Parcial'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _paymentStatus = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesCtrl,
                        decoration: _dec(
                          'Notas (opcional)',
                          icon: Icons.notes_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child:
                              _saving
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text(
                                    'Crear orden',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  InputDecoration _dec(String label, {required IconData icon}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPERS COMPARTIDOS
// ══════════════════════════════════════════════════════════════════════════════

Color _statusColor(String status) {
  switch (status) {
    case 'PENDING':
      return AppColors.warning;
    case 'SENT':
      return Colors.blue.shade400;
    case 'PARTIAL':
      return Colors.orange.shade400;
    case 'RECEIVED':
      return AppColors.success;
    case 'CANCELLED':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'PENDING':
      return 'Pendiente';
    case 'SENT':
      return 'Enviado';
    case 'PARTIAL':
      return 'Parcial';
    case 'RECEIVED':
      return 'Recibido';
    case 'CANCELLED':
      return 'Cancelado';
    default:
      return status;
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
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
