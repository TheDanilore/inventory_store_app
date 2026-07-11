import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_item_model.dart';

import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exit_detail_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits_state.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_exit_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';

class InventoryExitsScreen extends StatefulWidget {
  const InventoryExitsScreen({super.key});

  @override
  State<InventoryExitsScreen> createState() => _InventoryExitsScreenState();
}

class _InventoryExitsScreenState extends State<InventoryExitsScreen> {
  InventoryExitsCubit get cubit => context.read<InventoryExitsCubit>();
  final _searchCtrl = TextEditingController();

  bool _hasDraft = false;
  InventoryExitEntity? _selectedExit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<InventoryExitsCubit>();
      _searchCtrl.text = cubit.state.searchQuery;
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

  Future<List<InventoryExitItemModel>> _loadItems(
    InventoryExitEntity exitData,
  ) async {
    final getItemsUseCase = sl<GetExitItemsUseCase>();
    final itemsList = await getItemsUseCase.call(exitData.id);
    return itemsList.map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variant = r['product_variants'] as Map<String, dynamic>?;
      final variantId = r['variant_id'] as String?;

      final vavList =
          variant?['variant_attribute_values'] as List<dynamic>? ?? [];
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
      final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
      if (imagesList.isNotEmpty) {
        final variantImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
          (img) => img['variant_id'] == variantId,
          orElse: () => <String, dynamic>{},
        );
        if (variantImage.isNotEmpty && variantImage['image_url'] != null) {
          finalImageUrl = variantImage['image_url'] as String;
        } else {
          final mainImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
            (img) => img['is_main'] == true,
            orElse: () => imagesList.first as Map<String, dynamic>,
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
  }

  Future<void> _loadItemsAndShowDetailMobile(
    BuildContext context,
    InventoryExitEntity exitData,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => InventoryExitDetailSheet(
            exitData: exitData,
            isBottomSheet: true,
            loadItems: () => _loadItems(exitData),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryExitsCubit, InventoryExitsState>(
      builder: (context, state) {
        final cubit = context.read<InventoryExitsCubit>();
        if (cubit.state.errorMessage != null && !cubit.state.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppSnackbar.show(
              context,
              message: cubit.state.errorMessage!,
              type: SnackbarType.error,
            );
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 800;

            // Si es tablet pero borramos la búsqueda, limpiamos la selección si ya no existe
            if (isTablet && _selectedExit != null) {
              final exists = cubit.state.exits.any(
                (e) => e.id == _selectedExit!.id,
              );
              if (!exists && cubit.state.exits.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedExit = null);
                  }
                });
              }
            }

            return Stack(
              children: [
                isTablet
                    ? _buildTabletLayout(context, state, cubit)
                    : _buildMobileLayout(context, state, cubit),

                // ── Paginación anclada al fondo ──
                if (cubit.state.totalPages > 1 && !cubit.state.isLoading)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: isTablet ? constraints.maxWidth * 0.6 : 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.9),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: AdminPageBlocks(
                          currentPage: cubit.state.currentPage,
                          totalPages: cubit.state.totalPages,
                          onPageChanged: cubit.changePage,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  right: 24,
                  bottom: 24,
                  child: FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await context.push<bool>(
                        '/admin/inventory-exit-form',
                      );
                      if (result == true) {
                        cubit.loadExits(isRefresh: true);
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
                ),
              ],
            );
          },
        );
      },
    );
  }

  // LAYOUTS

  Widget _buildMobileLayout(
    BuildContext context,
    InventoryExitsState state,
    InventoryExitsCubit cubit,
  ) {
    return _buildListContent(cubit, isTablet: false);
  }

  Widget _buildTabletLayout(
    BuildContext context,
    InventoryExitsState state,
    InventoryExitsCubit cubit,
  ) {
    return Row(
      children: [
        // Panel Izquierdo: Lista
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: _buildListContent(cubit, isTablet: true),
          ),
        ),
        // Panel Derecho: Detalles
        Expanded(
          flex: 6,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                _selectedExit == null
                    ? Container(
                      key: const ValueKey('empty_detail'),
                      color: AppColors.background,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.outbox_rounded,
                              size: 64,
                              color: AppColors.border,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Selecciona una salida para ver sus detalles',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : InventoryExitDetailSheet(
                      key: ValueKey('detail_${_selectedExit!.id}'),
                      exitData: _selectedExit!,
                      isBottomSheet: false,
                      loadItems: () => _loadItems(_selectedExit!),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(
    InventoryExitsCubit cubit, {
    required bool isTablet,
  }) {
    final totalCost = cubit.state.exits.fold<double>(
      0,
      (s, e) => s + e.totalCost,
    );

    return RefreshIndicator(
      color: AppColors.danger,
      onRefresh: () => cubit.loadExits(isRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Borrador ──
          if (_hasDraft)
            SliverToBoxAdapter(
              child: Container(
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
                        'Borrador en progreso',
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
                        if (!mounted) return;
                        if (result == true) {
                          context.read<InventoryExitsCubit>().initLoad();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.warning.withValues(
                          alpha: 0.2,
                        ),
                        foregroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Resumen ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _SummaryTile(
                    label: 'Salidas',
                    value: '${cubit.state.exits.length}',
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

          // ── Filtros (Sticky) ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyFiltersDelegate(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        controller: _searchCtrl,
                        hint: 'Buscar motivo o notas...',
                        onChanged: cubit.updateSearch,
                        onClear: () {
                          _searchCtrl.clear();
                          cubit.updateSearch('');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    DateFilterCalendar(
                      dateRange:
                          cubit.state.startDate != null &&
                                  cubit.state.endDate != null
                              ? DateTimeRange(
                                start: cubit.state.startDate!,
                                end: cubit.state.endDate!,
                              )
                              : null,
                      onDateRangeSelected: (picked) => cubit.updateDateRange(
                        picked.start,
                        picked.end,
                      ),
                      onClear: () => cubit.updateDateRange(null, null),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Lista ──
          if (cubit.state.isLoading && cubit.state.exits.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: KardexSkeleton()),
            )
          else if (cubit.state.errorMessage != null &&
              cubit.state.exits.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  cubit.state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (cubit.state.exits.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Sin Resultados',
                message:
                      cubit.state.searchQuery.isEmpty &&
                              cubit.state.startDate == null &&
                              cubit.state.endDate == null
                        ? 'No hay salidas registradas'
                        : 'Sin resultados para los filtros',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final exit = cubit.state.exits[i];
                  final isSelected = isTablet && _selectedExit?.id == exit.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExitCard(
                      exitData: exit,
                      isSelected: isSelected,
                      onTap: () {
                        if (isTablet) {
                          setState(() => _selectedExit = exit);
                        } else {
                          _loadItemsAndShowDetailMobile(context, exit);
                        }
                      },
                    ),
                  );
                }, childCount: cubit.state.exits.length),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DELEGATES
// ══════════════════════════════════════════════════════════════════════════════

class _StickyFiltersDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyFiltersDelegate({required this.child});

  @override
  double get minExtent => 70.0;
  @override
  double get maxExtent => 70.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyFiltersDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _ExitCard extends StatelessWidget {
  final InventoryExitEntity exitData;
  final VoidCallback onTap;
  final bool isSelected;

  const _ExitCard({
    required this.exitData,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.danger.withValues(alpha: 0.05)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.danger.withValues(alpha: 0.5)
                    : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
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
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary),
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
