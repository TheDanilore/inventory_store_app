import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/models/entry_item_ui.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/purchase_order_model.dart';
import 'package:inventory_store_app/providers/admin/purchase_orders_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/purchase_orders/po_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/purchase_orders/po_detail_sheet.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _searchCtrl = TextEditingController();
  bool _hasDraft = false;
  Timer? _debounce;

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
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PurchaseOrdersProvider>();
      provider.loadOrders(reset: true);
      _searchCtrl.text = provider.searchText;
    });
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('po_form_draft_v1');
    if (str != null) {
      try {
        final data = jsonDecode(str) as Map<String, dynamic>;
        final items = data['items'] as List?;
        setState(() {
          _hasDraft = items != null && items.isNotEmpty;
        });
      } catch (_) {
        if (mounted) setState(() => _hasDraft = false);
      }
    } else {
      if (mounted) setState(() => _hasDraft = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final provider = context.read<PurchaseOrdersProvider>();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: provider.dateRange,
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
      provider.setDateRange(picked);
    }
  }

  // Helpers para generar modelos dummy
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

  void _showDetail(BuildContext context, PurchaseOrderModel po) {
    final provider = context.read<PurchaseOrdersProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => PODetailSheet(
            po: po,
            loadItems: () => provider.loadItemsForOrder(po.id),
            onReceive: () async {
              final items = await provider.loadItemsForOrder(po.id);
              if (!context.mounted) return;

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

              if (!context.mounted) return;
              Navigator.pop(context); // Cierra BottomSheet

              final result = await context.push<bool>(
                '/admin/inventory-entry-form?purchaseOrderId=${po.id}',
                extra: {
                  'purchaseOrderId': po.id,
                  'prefillSupplierId': po.supplierId,
                  'prefillSupplierName': po.supplierName,
                  'prefillItems': entryItems,
                  'prefillDocumentType': po.documentType,
                  'prefillDocumentNumber': po.documentNumber,
                  'prefillDocumentDate': po.createdAt,
                },
              );
              if (result == true && context.mounted) {
                context.read<PurchaseOrdersProvider>().loadOrders();
              }
            },
            onUpdateStatus:
                (status) => provider.updateOrderStatus(po.id, status),
          ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseOrdersProvider>(
      builder: (context, provider, child) {
        if (provider.errorMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              context,
              message: provider.errorMessage,
              type: SnackbarType.error,
            );
            provider.clearError();
          });
        }

        final filtered = provider.orders;
        final totalAmount = provider.totalAmountFiltered;
        final pendingCount = provider.pendingCountFiltered;

        return AdminLayout(
          title: 'Órdenes de Compra',
          showBackButton: true,
          body: Column(
            children: [
              // ── Borrador ──────────────────────────────────────────────────
              if (_hasDraft)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_document,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tienes un borrador de compra en progreso.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          final result = await context.push<bool>(
                            '/admin/purchase-order-form',
                          );
                          _checkDraft();
                          if (result == true && context.mounted) {
                            context.read<PurchaseOrdersProvider>().loadOrders();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warning.withValues(
                            alpha: 0.2,
                          ),
                          foregroundColor: AppColors.warning,
                        ),
                        child: const Text('Continuar'),
                      ),
                    ],
                  ),
                ),

              // ── Resumen ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _SummaryTile(
                      label: 'Órdenes',
                      value: '${filtered.length}',
                      icon: Icons.shopping_cart_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      label: 'Total Pág.',
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

              // ── Filtros ───────────────────────────────────────────────────
              Padding(
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
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 300),
                                () => provider.setSearchText(v),
                              );
                            },
                            onSubmitted: (v) {
                              _debounce?.cancel();
                              provider.setSearchText(v);
                            },
                            onClear: () {
                              _debounce?.cancel();
                              _searchCtrl.clear();
                              provider.setSearchText('');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DateRangeButton(
                          dateRange: provider.dateRange,
                          onTap: () => _pickDateRange(context),
                          onClear: () => provider.setDateRange(null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            _statusLabels.entries.map((e) {
                              final sel = provider.statusFilter == e.key;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(e.value),
                                  selected: sel,
                                  onSelected:
                                      (_) => provider.setStatusFilter(e.key),
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
              const SizedBox(height: 6),

              // ── Lista ─────────────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: provider.isLoading
                      ? ListView.separated(
                          key: const ValueKey('loading'),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          itemCount: 5,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 10),
                          itemBuilder:
                              (_, _) => AppShimmer(
                                width: double.infinity,
                                height: 90,
                                borderRadius: 14,
                              ),
                        )
                      : filtered.isEmpty
                          ? AppEmptyState(
                              key: const ValueKey('empty'),
                              icon: Icons.shopping_cart_outlined,
                              title: 'Sin Resultados',
                              message:
                                  'Sin resultados para los filtros aplicados',
                            )
                          : Column(
                              key: ValueKey(
                                '${provider.statusFilter}_${provider.currentPage}',
                              ),
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                  child: Row(
                                    children: [
                                      const Spacer(),
                                      Text(
                                        'Pág. ${provider.currentPage + 1} / ${provider.totalPages}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: RefreshIndicator(
                                    color: AppColors.primary,
                                    onRefresh:
                                        () => provider.loadOrders(reset: true),
                                    child: ListView.separated(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        0,
                                      ),
                                      itemCount: filtered.length,
                                      separatorBuilder:
                                          (_, _) => const SizedBox(height: 10),
                                      itemBuilder:
                                          (_, i) => POCard(
                                            po: filtered[i],
                                            onTap: () => _showDetail(
                                              context,
                                              filtered[i],
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                                if (provider.totalPages > 1)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      8,
                                    ),
                                    child: AdminPageBlocks(
                                      currentPage: provider.currentPage,
                                      totalPages: provider.totalPages,
                                      onPageChanged:
                                          (p) => provider.goToPage(p),
                                    ),
                                  ),
                              ],
                            ),
                ),
              ),
            ],
          ),

          // ── FAB NUEVA ORDEN ──
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final result = await context.push<bool>(
                '/admin/purchase-order-form',
              );
              if (result == true && context.mounted) {
                context.read<PurchaseOrdersProvider>().loadOrders();
              }
              _checkDraft();
            },
            icon: Icon(_hasDraft ? Icons.edit_note_rounded : Icons.add_rounded),
            label: Text(
              _hasDraft ? 'Continuar Borrador' : 'Nueva orden',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor:
                _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
            foregroundColor: Colors.white,
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.75),
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
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    required this.onClear,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    textInputAction: TextInputAction.search,
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
      contentPadding: const EdgeInsets.symmetric(vertical: 13),
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

  String _formatRange(DateTimeRange range) {
    final fmt = DateFormat('d MMM', 'es');
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = dateRange != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: hasDate
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 6),
                        Text(
                          _formatRange(dateRange!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onClear,
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
