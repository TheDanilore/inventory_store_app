import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batch_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batch_detail_pane.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'dart:async';

class InventoryBatchesTab extends StatefulWidget {
  const InventoryBatchesTab({super.key});

  @override
  State<InventoryBatchesTab> createState() => _InventoryBatchesTabState();
}

class _InventoryBatchesTabState extends State<InventoryBatchesTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  InventoryBatchItem? _selectedBatch;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<InventoryCubit>().setBatchSearch(value);
    });
  }

  void _onSearchSubmitted(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    context.read<InventoryCubit>().setBatchSearch(value);
  }

  void _selectBatch(InventoryBatchItem batch, {required bool isTablet}) {
    if (isTablet) {
      setState(() => _selectedBatch = batch);
    } else {
      InventoryBatchDetailPane.showAsBottomSheet(context, batch);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        final cubitState = context.read<InventoryCubit>().state;
        final loadedState = state is InventoryLoaded
            ? state
            : (cubitState is InventoryLoaded ? cubitState : null);

        if (loadedState == null) {
          if (state is InventoryError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final currentState = loadedState;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 840;

            // Auto-selección del primer lote en tablet/desktop para eliminar el desierto blanco
            if (isTablet && currentState.batchItems.isNotEmpty) {
              final exists = currentState.batchItems.any(
                (b) => b.id == _selectedBatch?.id,
              );
              if (!exists || _selectedBatch == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && currentState.batchItems.isNotEmpty) {
                    setState(() {
                      _selectedBatch = currentState.batchItems.first;
                    });
                  }
                });
              }
            }

            if (isTablet) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Lista Izquierda (42% de ancho en Desktop) ──
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      child: _buildListContent(
                        currentState,
                        state is InventoryLoading,
                        isTablet: true,
                      ),
                    ),
                  ),

                  // ── Panel de Inspección Derecho (58% de ancho) ──
                  Expanded(
                    flex: 7,
                    child: Container(
                      color: AppColors.background,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child:
                          _selectedBatch == null
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 56,
                                      color: AppColors.border,
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'No hay lotes disponibles para inspeccionar',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: InventoryBatchDetailPane(
                                  key: ValueKey('batch_${_selectedBatch!.id}'),
                                  batch: _selectedBatch!,
                                  isEmbedded: true,
                                ),
                              ),
                    ),
                  ),
                ],
              );
            }

            // Móvil: Lista a ancho completo
            return _buildListContent(
              currentState,
              state is InventoryLoading,
              isTablet: false,
            );
          },
        );
      },
    );
  }

  Widget _buildListContent(
    InventoryLoaded state,
    bool isLoading, {
    required bool isTablet,
  }) {
    final cubit = context.read<InventoryCubit>();
    final totalBatches =
        state.countVencido +
        state.countCritico +
        state.countProximo +
        state.countNormal;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.slash &&
              !_searchFocusNode.hasFocus) {
            _searchFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_searchCtrl.text.isNotEmpty) {
              _searchCtrl.clear();
              cubit.setBatchSearch('');
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Métricas de Lotes Interactivas (Unificación de Tarjetas + Filtros) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _InteractiveMetricCard(
                          label: 'Todos',
                          value: '$totalBatches',
                          icon: Icons.apps_rounded,
                          color: AppColors.primary,
                          isSelected: state.batchStatusFilter == 'Todos',
                          onTap: () => cubit.setBatchStatus('Todos'),
                        ),
                        const SizedBox(width: 8),
                        _InteractiveMetricCard(
                          label: 'Vencidos',
                          value: '${state.countVencido}',
                          icon: Icons.block_rounded,
                          color: AppColors.danger,
                          isSelected: state.batchStatusFilter == 'vencido',
                          highlight: state.countVencido > 0,
                          onTap: () => cubit.setBatchStatus('vencido'),
                        ),
                        const SizedBox(width: 8),
                        _InteractiveMetricCard(
                          label: 'Críticos',
                          value: '${state.countCritico}',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          isSelected: state.batchStatusFilter == 'critico',
                          highlight: state.countCritico > 0,
                          onTap: () => cubit.setBatchStatus('critico'),
                        ),
                        const SizedBox(width: 8),
                        _InteractiveMetricCard(
                          label: 'Próximos',
                          value: '${state.countProximo}',
                          icon: Icons.schedule_rounded,
                          color: AppColors.info,
                          isSelected: state.batchStatusFilter == 'proximo',
                          highlight: state.countProximo > 0,
                          onTap: () => cubit.setBatchStatus('proximo'),
                        ),
                        const SizedBox(width: 8),
                        _InteractiveMetricCard(
                          label: 'Normal',
                          value: '${state.countNormal}',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                          isSelected: state.batchStatusFilter == 'normal',
                          onTap: () => cubit.setBatchStatus('normal'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Buscador Sticky Compacto ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyBatchesHeaderDelegate(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _SearchField(
                  controller: _searchCtrl,
                  focusNode: _searchFocusNode,
                  hint: 'Buscar por producto o lote... (presiona /)',
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                  isLoading: state.isSearchingBatches,
                  onClear: () {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _searchCtrl.clear();
                    cubit.setBatchSearch('');
                  },
                ),
              ),
            ),
          ),

          // ── Indicador de búsqueda no destructivo ──
          if (state.isSearchingBatches)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: AppColors.primary,
                ),
              ),
            ),

          // ── Resumen de Resultados ──
          if (!isLoading && state.batchItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lotes Encontrados (${state.batchItems.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Página ${state.currentBatchPage + 1} de ${state.totalBatchPages}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Lista de Lotes ──
          if ((isLoading || state.isSearchingBatches) && state.batchItems.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _InventoryBatchesSkeleton()),
            )
          else if (state.batchItems.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Sin Resultados',
                message: 'No se encontraron lotes con estos criterios',
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                state.totalBatchPages > 1 ? 90 : 20,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final batch = state.batchItems[i];
                  final isSelected = isTablet && _selectedBatch?.id == batch.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InventoryBatchCard(
                      batch: batch,
                      isSelected: isSelected,
                      onTap: () => _selectBatch(batch, isTablet: isTablet),
                    ),
                  );
                }, childCount: state.batchItems.length),
              ),
            ),

          // ── Paginación Inferior ──
          if (!isLoading && state.totalBatchPages > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: AdminPageBlocks(
                  currentPage: state.currentBatchPage,
                  totalPages: state.totalBatchPages,
                  onPageChanged: (page) => cubit.setBatchPage(page),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPONENTES AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _StickyBatchesHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyBatchesHeaderDelegate({required this.child});

  @override
  double get minExtent => 68.0;
  @override
  double get maxExtent => 68.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyBatchesHeaderDelegate oldDelegate) => true;
}

class _InteractiveMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool highlight;
  final VoidCallback onTap;

  const _InteractiveMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? color.withValues(alpha: 0.12)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isSelected
                      ? color
                      : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : AppColors.cardShadow(opacity: 0.02),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? color
                          : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? color
                              : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color:
                          isSelected
                              ? color
                              : AppColors.textPrimary,
                      height: 1.1,
                    ),
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;
  final bool isLoading;

  const _SearchField({
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    required this.onClear,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 13.5),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.textSecondary,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, val, _) {
                if (val.text.isNotEmpty && !isLoading) {
                  return IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textSecondary,
                    onPressed: onClear,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _InventoryBatchesSkeleton extends StatelessWidget {
  const _InventoryBatchesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const AppShimmer(width: 48, height: 48, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmer(width: 140, height: 16, borderRadius: 4),
                    SizedBox(height: 6),
                    AppShimmer(width: 100, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              const AppShimmer(width: 65, height: 24, borderRadius: 8),
            ],
          ),
        );
      },
    );
  }
}
