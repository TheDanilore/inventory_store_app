import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/models/inventory_entry_model.dart';
import 'package:inventory_store_app/providers/admin/inventory_entries_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/inventory_entries/inventory_entry_detail_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/services/admin/inventory_entries_service.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InventoryEntriesScreen extends StatefulWidget {
  const InventoryEntriesScreen({super.key});

  @override
  State<InventoryEntriesScreen> createState() => _InventoryEntriesScreenState();
}

class _InventoryEntriesScreenState extends State<InventoryEntriesScreen> {
  final _searchCtrl = TextEditingController();
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryEntriesProvider>();
      _searchCtrl.text = provider.searchQuery;
      provider.init();
    });
    _checkDraft();
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsString = prefs.getString('inventory_entry_draft');
    if (mounted) {
      setState(() {
        _hasDraft =
            itemsString != null &&
            itemsString.isNotEmpty &&
            itemsString != '[]';
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItemsAndShowDetail(
    BuildContext context,
    InventoryEntryModel entry,
  ) async {
    final service = InventoryEntriesService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => InventoryEntryDetailSheet(
            entry: entry,
            loadItems: () async {
              final itemsDynamic = await service.getEntryItems(entry.id);
              return itemsDynamic.map((r) {
                final prod = r['products'] as Map<String, dynamic>?;
                final variantData =
                    r['product_variants'] as Map<String, dynamic>?;
                final variantId = r['variant_id'] as String?;

                final vavList =
                    variantData?['variant_attribute_values']
                        as List<dynamic>? ??
                    [];
                final List<String> attrValues = [];

                for (var vav in vavList) {
                  final av = vav['attribute_values'] as Map<String, dynamic>?;
                  if (av != null && av['value'] != null) {
                    attrValues.add(av['value'].toString());
                  }
                }

                final attrsText = attrValues.join(' · ');
                final bool usesBatches = prod?['uses_batches'] == true;

                String? finalImageUrl;
                final imagesList =
                    prod?['product_images'] as List<dynamic>? ?? [];
                if (imagesList.isNotEmpty) {
                  final variantImage = imagesList
                      .cast<Map<String, dynamic>>()
                      .firstWhere(
                        (img) => img['variant_id'] == variantId,
                        orElse: () => <String, dynamic>{},
                      );
                  if (variantImage.isNotEmpty &&
                      variantImage['image_url'] != null) {
                    finalImageUrl = variantImage['image_url'] as String;
                  } else {
                    final mainImage = imagesList
                        .cast<Map<String, dynamic>>()
                        .firstWhere(
                          (img) => img['is_main'] == true,
                          orElse:
                              () => imagesList.first as Map<String, dynamic>,
                        );
                    finalImageUrl = mainImage['image_url'] as String?;
                  }
                }

                return InventoryEntryItemModel(
                  id: r['id'] as String? ?? '',
                  entryId: entry.id,
                  productId: prod?['id'] as String? ?? '',
                  variantId: variantId ?? '',
                  productName: prod?['name'] as String? ?? '—',
                  variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
                  quantity: (r['quantity'] as num).toDouble(),
                  unitCost: (r['unit_cost'] as num).toDouble(),
                  batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
                  expiryDate:
                      r['expiry_date'] != null
                          ? DateTime.tryParse(r['expiry_date'] as String)
                          : null,
                  usesBatches: usesBatches,
                  imageUrl: finalImageUrl,
                );
              }).toList();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryEntriesProvider>(
      builder: (context, provider, child) {
        if (provider.errorMessage.isNotEmpty && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              context,
              message: provider.errorMessage,
              type: SnackbarType.error,
            );
            provider.clearError();
          });
        }

        final double totalAmount = provider.entries.fold<double>(
          0,
          (s, e) => s + e.totalAmount,
        );

        return AdminLayout(
          title: 'Historial de Entradas',
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
                      const Icon(Icons.edit_document, color: AppColors.warning),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tienes un borrador de entrada en progreso.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await context.push<bool>(
                            '/admin/inventory-entry-form',
                          );
                          _checkDraft();
                          if (result == true && context.mounted) {
                            context.read<InventoryEntriesProvider>().init();
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Resumen ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _SummaryChip(
                      label: 'Página actual',
                      value: '${provider.entries.length}',
                      icon: Icons.move_to_inbox_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _SummaryChip(
                      label: 'Inversión (pág)',
                      value: 'S/ ${totalAmount.toStringAsFixed(2)}',
                      icon: Icons.payments_rounded,
                      color: AppColors.teal,
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
                            hint: 'Buscar proveedor o comprobante...',
                            onChanged: (v) {},
                            onSubmitted: (v) => provider.setSearchQuery(v),
                            onClear: () {
                              _searchCtrl.clear();
                              provider.setSearchQuery('');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        DateFilterCalendar(
                          dateRange: provider.dateRange,
                          onDateRangeSelected: provider.setDateRange,
                          onClear: () => provider.setDateRange(null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            provider.availableWarehouses.map((w) {
                              final sel = provider.warehouseFilter == w;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(w),
                                  selected: sel,
                                  onSelected:
                                      (_) => provider.setWarehouseFilter(w),
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

              const SizedBox(height: 6),

              // ── Lista ─────────────────────────────────────────────────────
              Expanded(
                child:
                    provider.isLoading
                        ? const _EntriesSkeleton()
                        : provider.entries.isEmpty
                        ? _EmptyState(
                          icon: Icons.inbox_outlined,
                          message:
                              provider.searchQuery.isEmpty &&
                                      provider.dateRange == null &&
                                      provider.warehouseFilter == 'Todos'
                                  ? 'No hay entradas registradas'
                                  : 'Sin resultados para los filtros aplicados',
                        )
                        : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                                onRefresh: () => provider.loadEntries(page: 0),
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    0,
                                  ),
                                  itemCount: provider.entries.length,
                                  separatorBuilder:
                                      (_, _) => const SizedBox(height: 10),
                                  itemBuilder:
                                      (_, i) => _EntryCard(
                                        entry: provider.entries[i],
                                        onTap:
                                            () => _loadItemsAndShowDetail(
                                              context,
                                              provider.entries[i],
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
                                  onPageChanged: provider.goToPage,
                                ),
                              ),
                          ],
                        ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final result = await context.push<bool>(
                '/admin/inventory-entry-form',
              );
              if (result == true) {
                provider.loadEntries(page: 0); // Refrescar en la misma pantalla
              }
              _checkDraft();
            },
            icon: Icon(_hasDraft ? Icons.edit_note_rounded : Icons.add_rounded),
            label: Text(_hasDraft ? 'Continuar Borrador' : 'Nueva entrada'),
            backgroundColor:
                _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
            foregroundColor: _hasDraft ? Colors.white : Colors.white,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY CARD
// ══════════════════════════════════════════════════════════════════════════════

class _EntryCard extends StatelessWidget {
  final InventoryEntryModel entry;
  final VoidCallback onTap;
  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final hasDoc =
        entry.documentType != 'NINGUNO' &&
        entry.documentNumber != null &&
        entry.documentNumber!.isNotEmpty;

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
                          entry.createdAt != null
                              ? fmt.format(entry.createdAt!.toLocal())
                              : '',
                          style: const TextStyle(
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
                        style: const TextStyle(
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
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
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

class _EntriesSkeleton extends StatelessWidget {
  const _EntriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppShimmer(width: 40, height: 40, borderRadius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 120, height: 14, borderRadius: 4),
                        SizedBox(height: 6),
                        AppShimmer(width: 80, height: 10, borderRadius: 4),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      AppShimmer(width: 60, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      AppShimmer(width: 40, height: 10, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  AppShimmer(width: 80, height: 20, borderRadius: 8),
                  SizedBox(width: 6),
                  AppShimmer(width: 100, height: 20, borderRadius: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
