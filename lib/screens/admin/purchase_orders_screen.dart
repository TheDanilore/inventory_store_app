import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/variant_attribute_value_model.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/screens/admin/purchase_order_form_screen.dart';
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
  final String productId;
  final String variantId;
  final String? productName;
  final String variantAttrs;
  final String? sku;
  final double quantityOrdered;
  final double quantityReceived;
  final double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;
  final bool usesBatches;

  const _POItemModel({
    required this.productId,
    required this.variantId,
    this.productName,
    required this.variantAttrs,
    this.sku,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
    required this.batchNumber,
    this.expiryDate,
    required this.usesBatches,
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
          product_id, variant_id,
          quantity_ordered, quantity_received, unit_cost,
          batch_number, expiry_date,
          products(name, uses_batches),
          product_variants(sku, variant_attribute_values(attribute_values(id, value, attributes(id, name))))
        ''')
        .eq('purchase_order_id', poId);

    return (resp as List).map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variant = r['product_variants'] as Map<String, dynamic>?;

      // Parseamos los atributos reutilizando VariantAttributeValueModel.fromJson,
      // que ya sabe leer la estructura: variant_attribute_values → attribute_values → attributes
      final List<VariantAttributeValueModel> parsedAttrs = [];
      if (variant != null && variant['variant_attribute_values'] is List) {
        for (final vav in variant['variant_attribute_values'] as List) {
          try {
            parsedAttrs.add(
              VariantAttributeValueModel.fromJson(
                Map<String, dynamic>.from(vav as Map),
              ),
            );
          } catch (_) {
            // ignorar entradas malformadas
          }
        }
      }

      // Construimos el texto legible de atributos: "Talla: M · Color: Rojo"
      final attrsText = parsedAttrs.isNotEmpty
          ? parsedAttrs
              .map((a) =>
                  a.attributeName.isNotEmpty
                      ? '${a.attributeName}: ${a.value}'
                      : a.value)
              .join(' · ')
          : 'Única';

      return _POItemModel(
        productId: r['product_id'] as String,
        variantId: r['variant_id'] as String,
        productName: prod?['name'] as String?,
        variantAttrs: attrsText,
        sku: variant?['sku'] as String?,
        quantityOrdered: (r['quantity_ordered'] as num).toDouble(),
        quantityReceived: (r['quantity_received'] as num?)?.toDouble() ?? 0,
        unitCost: (r['unit_cost'] as num).toDouble(),
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
        expiryDate:
            r['expiry_date'] != null
                ? DateTime.tryParse(r['expiry_date'] as String)
                : null,
        usesBatches: prod?['uses_batches'] as bool? ?? false,
      );
    }).toList();
  }

  // Helpers para generar modelos dummy que eviten errores al pasar a la pantalla de recepción
  ProductModel _dummyProduct(String id, String name, bool usesBatches) {
    return ProductModel.fromJson({
      'id': id,
      'name': name,
      'is_active': true,
      'stock_control': true,
      'uses_batches': usesBatches,
      'product_type': 'good',
      'unit_cost': 0,
      'sale_price': 0,
    });
  }

  ProductVariantModel _dummyVariant(String id, String productId, String attrs) {
    return ProductVariantModel.fromJson({
      'id': id,
      'product_id': productId,
      'attributes': {'label': attrs},
      'is_active': true,
      'unit_cost': 0,
    });
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
                          product: _dummyProduct(
                            i.productId,
                            i.productName ?? '—',
                            i.usesBatches,
                          ),
                          variant: _dummyVariant(
                            i.variantId,
                            i.productId,
                            i.variantAttrs,
                          ),
                          quantity: i.quantityOrdered - i.quantityReceived,
                          unitCost: i.unitCost,
                          batchNumber: i.batchNumber,
                          expiryDate: i.expiryDate,
                        ),
                      )
                      .where((e) => e.quantity > 0)
                      .toList();

              if (!mounted) return;
              Navigator.pop(context); // Cierra el BottomSheet

              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => InventoryEntryFormScreen(
                        purchaseOrderId: po.id,
                        prefillSupplierId: po.supplierId,
                        prefillSupplierName: po.supplierName,
                        prefillItems: entryItems,
                        // PASANDO LOS DATOS DEL COMPROBANTE
                        prefillDocumentType: po.documentType,
                        prefillDocumentNumber: po.documentNumber,
                        prefillDocumentDate:
                            po.createdAt, // Usamos la fecha de la orden como referencia
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
                    style: const TextStyle(
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

            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),

      // ── FAB NUEVA ORDEN ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const PurchaseOrderFormScreen()),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva orden',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
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

class _POCard extends StatelessWidget {
  final _POModel po;
  final VoidCallback onTap;

  const _POCard({required this.po, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    po.supplierName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _Pill(
                  icon: Icons.circle,
                  label: _statusLabel(po.status),
                  color: _statusColor(po.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${po.itemCount} productos',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy', 'es').format(po.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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
      ),
    );
  }
}

class _PODetailSheet extends StatefulWidget {
  final _POModel po;
  final Future<List<_POItemModel>> Function() loadItems;
  final VoidCallback onReceive;
  final ValueChanged<String> onUpdateStatus;

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

  @override
  void initState() {
    super.initState();
    widget.loadItems().then((value) {
      if (mounted) setState(() => _items = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalle de Orden',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                _Pill(
                  icon: Icons.circle,
                  label: _statusLabel(widget.po.status),
                  color: _statusColor(widget.po.status),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Proveedor y Finanzas
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PROVEEDOR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.po.supplierName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Divider(height: 24, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MÉTODO DE PAGO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Text(
                                  widget.po.paymentMethod,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'FECHA EMISIÓN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(widget.po.createdAt),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                  Text(
                                    'S/ ${widget.po.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PAGADO',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                  Text(
                                    'S/ ${widget.po.amountPaid.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'DEUDA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                  Text(
                                    'S/ ${widget.po.pending.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          widget.po.pending > 0
                                              ? AppColors.danger
                                              : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lista de Items
                  const Text(
                    'Productos Solicitados',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (_items == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_items!.isEmpty)
                    const Text(
                      'No hay productos',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    ..._items!.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName ?? '—',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (item.variantAttrs != 'Única')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        item.variantAttrs,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Recibido: ${item.quantityReceived.toInt()} / ${item.quantityOrdered.toInt()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          item.fullyReceived
                                              ? AppColors.success
                                              : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'S/ ${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Acciones Administrativas
                  if (widget.po.status == 'PENDING') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => widget.onUpdateStatus('SENT'),
                        child: const Text(
                          'Marcar como ENVIADA',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.po.status == 'SENT' ||
                      widget.po.status == 'PARTIAL') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.inventory_rounded, size: 20),
                        label: const Text(
                          'Recepcionar Mercadería',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: widget.onReceive,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (widget.po.status != 'CANCELLED' &&
                      widget.po.status != 'RECEIVED')
                    Center(
                      child: TextButton(
                        onPressed: () => widget.onUpdateStatus('CANCELLED'),
                        child: const Text(
                          'Anular Orden',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                child: const Icon(
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
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w800,
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
          style: const TextStyle(
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
