import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/inventory_exit_item_model.dart';
import 'package:inventory_store_app/models/inventory_exit_model.dart';
import 'package:inventory_store_app/providers/admin/inventory_exits_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/inventory_exits/inventory_exit_detail_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/services/admin/inventory_exits_service.dart';
import 'package:inventory_store_app/services/admin/inventory_exits_pdf_generator.dart';
import 'package:inventory_store_app/screens/admin/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class InventoryExitsScreen extends StatefulWidget {
  const InventoryExitsScreen({super.key});

  @override
  State<InventoryExitsScreen> createState() => _InventoryExitsScreenState();
}

class _InventoryExitsScreenState extends State<InventoryExitsScreen> {
  final _searchCtrl = TextEditingController();

  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InventoryExitsProvider>();
      _searchCtrl.text = provider.searchQuery;
      provider.initLoad();
    });
    _checkDraft();
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString('inventory_exit_draft');
    if (mounted) {
      setState(() {
        _hasDraft = draftString != null && draftString.isNotEmpty;
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
    InventoryExitModel exitData,
  ) async {
    final service = InventoryExitsService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => InventoryExitDetailSheet(
            exitData: exitData,
            loadItems: () async {
              final itemsList = await service.getExitItems(exitData.id);
              return itemsList.map((r) {
                final prod = r['products'] as Map<String, dynamic>?;
                final variant = r['product_variants'] as Map<String, dynamic>?;
                final variantId = r['variant_id'] as String?;

                final vavList =
                    variant?['variant_attribute_values'] as List<dynamic>? ??
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

                return InventoryExitItemModel(
                  id: r['id'] as String? ?? '',
                  exitId: exitData.id,
                  productId: prod?['id'] as String? ?? '',
                  variantId: variantId ?? '',
                  productName: prod?['name'] as String? ?? '—',
                  variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
                  quantity: (r['quantity'] as num).toDouble(),
                  unitCost: (r['unit_cost'] as num).toDouble(),
                  batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
                  usesBatches: usesBatches,
                  imageUrl: finalImageUrl,
                  sku: variant?['sku'] as String?,
                );
              }).toList();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryExitsProvider>(
      builder: (context, provider, _) {
        if (provider.errorMessage != null && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              context,
              message: provider.errorMessage!,
              type: SnackbarType.error,
            );
            // Si quieres limpiar el error después de mostrarlo para no repetirlo
            // provider.clearError();
          });
        }

        final totalCost = provider.exits.fold<double>(
          0,
          (s, e) => s + e.totalCost,
        );

        return AdminLayout(
          title: 'Salidas de Inventario',
          showBackButton: true,
          showSettingsButton: true,
          settingsActions: const [
            PopupMenuItem(
              value: 'pdf',
              child: Text('Exportar a PDF (Historial)'),
            ),
          ],
          onSettingsSelected: (val) {
            if (val == 'pdf' && provider.exits.isNotEmpty) {
              InventoryExitsPdfGenerator.shareReport(
                exits: provider.exits,
                dateRange: provider.dateRange,
              );
            } else if (val == 'pdf') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No hay datos para exportar')),
              );
            }
          },
          body: Column(
            children: [
              // ── Borrador ──
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
                          'Tienes un borrador de salida en progreso.',
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
                            '/admin/inventory-exit-form',
                          );
                          _checkDraft();
                          if (result == true && context.mounted) {
                            context.read<InventoryExitsProvider>().initLoad();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.warning.withValues(
                            alpha: 0.2,
                          ),
                          foregroundColor: AppColors.warning,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: RefreshIndicator(
                  color: AppColors.danger,
                  onRefresh: () => provider.loadExits(isRefresh: true),
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
                                value: '${provider.exits.length}',
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _SearchField(
                                  controller: _searchCtrl,
                                  hint: 'Buscar motivo o notas...',
                                  onChanged: provider.updateSearch,
                                  onClear: () {
                                    _searchCtrl.clear();
                                    provider.updateSearch('');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              DateFilterCalendar(
                                dateRange: provider.dateRange,
                                onDateRangeSelected: provider.updateDateRange,
                                onClear: () => provider.updateDateRange(null),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Lista ──
                      if (provider.isLoading && provider.exits.isEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(child: KardexSkeleton()),
                        )
                      else if (provider.errorMessage != null &&
                          provider.exits.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              provider.errorMessage!,
                              style: const TextStyle(color: AppColors.danger),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (provider.exits.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Sin Resultados',
                            message:
                                provider.searchQuery.isEmpty &&
                                        provider.dateRange == null
                                    ? 'No hay salidas registradas'
                                    : 'Sin resultados para los filtros',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ExitCard(
                                  exitData: provider.exits[i],
                                  onTap:
                                      () => _loadItemsAndShowDetail(
                                        context,
                                        provider.exits[i],
                                      ),
                                ),
                              ),
                              childCount: provider.exits.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Paginación anclada al fondo ──
              if (provider.totalPages > 1 && !provider.isLoading)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: AdminPageBlocks(
                      currentPage: provider.currentPage,
                      totalPages: provider.totalPages,
                      onPageChanged: provider.changePage,
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final result = await context.push<bool>(
                '/admin/inventory-exit-form',
              );
              if (result == true) {
                provider.loadExits(isRefresh: true);
              }
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
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _ExitCard extends StatelessWidget {
  final InventoryExitModel exitData;
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
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
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
                      exitData.createdAt != null
                          ? DateFormat(
                            'dd MMM yyyy - HH:mm',
                            'es',
                          ).format(exitData.createdAt!.toLocal())
                          : '—',
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
                      'COSTO DE SALIDA',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
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
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
