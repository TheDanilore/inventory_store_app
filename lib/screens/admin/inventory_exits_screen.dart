import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/inventory_exit_form_screen.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELOS LOCALES
// ══════════════════════════════════════════════════════════════════════════════

class _ExitModel {
  final String id;
  final DateTime createdAt;
  final String? warehouseName;
  final String? reason;
  final String? notes;
  final double totalCost;
  final int itemCount;

  const _ExitModel({
    required this.id,
    required this.createdAt,
    this.warehouseName,
    this.reason,
    this.notes,
    required this.totalCost,
    required this.itemCount,
  });

  factory _ExitModel.fromMap(Map<String, dynamic> m) {
    final wh = m['warehouses'] as Map<String, dynamic>?;
    final items = m['inventory_exit_items'] as List? ?? [];

    // Calculamos el costo total sumando (cantidad * costo unitario) de cada ítem
    double calculatedTotal = 0.0;
    for (var item in items) {
      final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final cost = (item['unit_cost'] as num?)?.toDouble() ?? 0.0;
      calculatedTotal += (qty * cost);
    }

    return _ExitModel(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      warehouseName: wh?['name'] as String?,
      reason: m['reason'] as String? ?? 'NO ESPECIFICADO',
      notes: m['notes'] as String?,
      totalCost: calculatedTotal,
      itemCount: items.length,
    );
  }
}

class _ExitItemModel {
  final String? productName;
  final String variantAttrs;
  final String? sku;
  final double quantity;
  final double unitCost;
  final String batchNumber;

  const _ExitItemModel({
    this.productName,
    required this.variantAttrs,
    this.sku,
    required this.quantity,
    required this.unitCost,
    required this.batchNumber,
  });

  double get subtotal => quantity * unitCost;
}

// ══════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════

class InventoryExitsScreen extends StatefulWidget {
  const InventoryExitsScreen({super.key});

  @override
  State<InventoryExitsScreen> createState() => _InventoryExitsScreenState();
}

class _InventoryExitsScreenState extends State<InventoryExitsScreen> {
  final _supabase = Supabase.instance.client;

  List<_ExitModel> _all = [];
  List<_ExitModel> _filtered = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _searchText = '';
  DateTimeRange? _dateRange;

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
          .from('inventory_exits')
          .select('''
            id, created_at, reason, notes,
            warehouses(name),
            inventory_exit_items(id, quantity, unit_cost)
          ''')
          .order('created_at', ascending: false)
          .limit(500);

      final exits =
          (resp as List)
              .map(
                (e) => _ExitModel.fromMap(Map<String, dynamic>.from(e as Map)),
              )
              .toList();

      if (mounted) {
        setState(() {
          _all = exits;
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
        _all.where((exit) {
          final matchSearch =
              _searchText.isEmpty ||
              (exit.reason ?? '').toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ||
              (exit.notes ?? '').toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ||
              (exit.warehouseName ?? '').toLowerCase().contains(
                _searchText.toLowerCase(),
              );

          final matchDate =
              _dateRange == null ||
              (!exit.createdAt.isBefore(_dateRange!.start) &&
                  !exit.createdAt.isAfter(
                    _dateRange!.end.add(const Duration(days: 1)),
                  ));

          return matchSearch && matchDate;
        }).toList();

    setState(() {
      _filtered = result;
      _currentPage = 0;
    });
  }

  Future<List<_ExitItemModel>> _loadItems(String exitId) async {
    final resp = await _supabase
        .from('inventory_exit_items')
        .select('''
          quantity, unit_cost, batch_number,
          products(name),
          product_variants(attributes, sku)
        ''')
        .eq('exit_id', exitId);

    return (resp as List).map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variant = r['product_variants'] as Map<String, dynamic>?;
      final attrs = Map<String, dynamic>.from(
        (variant?['attributes'] as Map?) ?? {},
      );
      final attrsText = attrs.values.map((e) => '$e').join(' · ');

      return _ExitItemModel(
        productName: prod?['name'] as String?,
        variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
        sku: variant?['sku'] as String?,
        quantity: (r['quantity'] as num).toDouble(),
        unitCost: (r['unit_cost'] as num?)?.toDouble() ?? 0.0,
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
      );
    }).toList();
  }

  void _showDetail(_ExitModel exitData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _ExitDetailSheet(
            exitData: exitData,
            loadItems: () => _loadItems(exitData.id),
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

    final totalCost = _filtered.fold<double>(0, (s, e) => s + e.totalCost);

    return AdminLayout(
      title: 'Salidas de Inventario',
      showBackButton: true,
      body: RefreshIndicator(
        color: AppColors.danger,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Resumen ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _SummaryTile(
                      label: 'Salidas',
                      value: '${_filtered.length}',
                      icon: Icons.output_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      label: 'Costo Total',
                      value: 'S/ ${totalCost.toStringAsFixed(2)}',
                      icon: Icons.money_off_rounded,
                      color: Colors.orange.shade700,
                    ),
                  ],
                ),
              ),
            ),

            // ── Filtros ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _searchCtrl,
                        hint: 'Buscar motivo o almacén...',
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
                    DateFilterCalendar(
                      dateRange: _dateRange,
                      onDateRangeSelected: (picked) {
                        setState(() => _dateRange = picked);
                        _applyFilters();
                      },
                      onClear: () {
                        setState(() => _dateRange = null);
                        _applyFilters();
                      },
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

            // ── Lista ──
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.danger),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message:
                      _all.isEmpty
                          ? 'No hay salidas registradas'
                          : 'Sin resultados para los filtros',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList.separated(
                  itemCount: pageItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder:
                      (_, i) => _ExitCard(
                        exitData: pageItems[i],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const InventoryExitFormScreen()),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.remove_circle_outline_rounded),
        label: const Text(
          'Nueva Salida',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

Color _reasonColor(String reason) {
  final r = reason.toUpperCase();
  if (r.contains('MERMA') || r.contains('DAÑO') || r.contains('VENCIMIENTO')) {
    return AppColors.danger;
  }
  if (r.contains('ROBO') || r.contains('PÉRDIDA')) return Colors.red.shade900;
  if (r.contains('CONSUMO') || r.contains('USO INTERNO')) {
    return Colors.blue.shade600;
  }
  if (r.contains('AJUSTE')) return Colors.orange.shade600;
  return AppColors.textSecondary;
}

class _ExitCard extends StatelessWidget {
  final _ExitModel exitData;
  final VoidCallback onTap;

  const _ExitCard({required this.exitData, required this.onTap});

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
                    exitData.reason ?? 'Sin motivo',
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
                  icon: Icons.warehouse_rounded,
                  label: exitData.warehouseName ?? 'Almacén Desconocido',
                  color: AppColors.textSecondary,
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
                      '${exitData.itemCount} productos',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat(
                        'dd MMM yyyy - HH:mm',
                        'es',
                      ).format(exitData.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Costo de salida',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textHint,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'S/ ${exitData.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExitDetailSheet extends StatefulWidget {
  final _ExitModel exitData;
  final Future<List<_ExitItemModel>> Function() loadItems;

  const _ExitDetailSheet({required this.exitData, required this.loadItems});

  @override
  State<_ExitDetailSheet> createState() => _ExitDetailSheetState();
}

class _ExitDetailSheetState extends State<_ExitDetailSheet> {
  List<_ExitItemModel>? _items;

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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalle de Salida',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                _Pill(
                  icon: Icons.info_outline_rounded,
                  label: widget.exitData.reason ?? 'Sin motivo',
                  color: _reasonColor(widget.exitData.reason ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          'ALMACÉN ORIGEN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.exitData.warehouseName ?? 'Desconocido',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        if (widget.exitData.notes != null &&
                            widget.exitData.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'NOTAS / JUSTIFICACIÓN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.exitData.notes!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],

                        const Divider(height: 24, color: AppColors.border),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'COSTO TOTAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Text(
                                  'S/ ${widget.exitData.totalCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'FECHA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Text(
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(widget.exitData.createdAt.toLocal()),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Productos Retirados',
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
                                  if (item.batchNumber != 'DEFAULT')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.tag_rounded,
                                            size: 10,
                                            color: AppColors.textHint,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Lote: ${item.batchNumber}',
                                            style: const TextStyle(
                                              color: AppColors.textHint,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity.toInt()} unidades x S/ ${item.unitCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
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
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
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

// ─── COMPONENTES COMPARTIDOS ──────────────────────────────────────────────────

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
