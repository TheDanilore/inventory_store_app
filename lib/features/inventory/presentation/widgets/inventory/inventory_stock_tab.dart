import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_card.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'dart:async';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';

class InventoryStockTab extends StatefulWidget {
  const InventoryStockTab({super.key});

  @override
  State<InventoryStockTab> createState() => _InventoryStockTabState();
}

class _InventoryStockTabState extends State<InventoryStockTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<InventoryCubit>().setStockSearch(value);
    });
  }

  void _openProductDetail(InventoryStockItem item) {
    context.push(
      '/admin/product/${item.productId}?variantId=${item.variantId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        if (state is InventoryInitial ||
            (state is InventoryLoading && state is! InventoryLoaded)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final loadedState =
            state is InventoryLoaded
                ? state
                : (state is InventoryLoading
                    ? context.read<InventoryCubit>().state as InventoryLoaded?
                    : null);

        if (loadedState == null && state is InventoryError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        final currentState =
            loadedState ??
            const InventoryLoaded(
              stockItems: [],
              batchItems: [],
              currentStockPage: 0,
              totalStockPages: 1,
              stockSearchText: '',
              stockCategoryFilter: 'Todos',
              categories: ['Todos'],
              globalTotalVariants: 0,
              globalTotalStock: 0,
              globalLowStockCount: 0,
              globalTotalCost: 0.0,
              currentBatchPage: 0,
              totalBatchPages: 1,
              batchSearchText: '',
              batchStatusFilter: 'Todos',
              countVencido: 0,
              countCritico: 0,
              countProximo: 0,
              countNormal: 0,
            );

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
                  context.read<InventoryCubit>().setStockSearch('');
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              if (isDesktop) {
                return _buildDesktopLayout(
                  currentState,
                  state is InventoryLoading,
                  cubit: context.read<InventoryCubit>(),
                );
              }

              return _buildListContent(currentState, state is InventoryLoading);
            },
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    InventoryLoaded state,
    bool isLoading, {
    required InventoryCubit cubit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Métricas y Filtros ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Métricas responsive con diseño alineado a Linear
              Row(
                children: [
                  _MetricCard(
                    label: 'Valor Total del Inv.',
                    value: 'S/ ${state.globalTotalCost.toStringAsFixed(2)}',
                    icon: Icons.monetization_on_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    label: 'Stock Total',
                    value: '${state.globalTotalStock} uds.',
                    icon: Icons.inventory_rounded,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    label: 'Productos Bajo Stock',
                    value: '${state.globalLowStockCount}',
                    icon: Icons.warning_amber_rounded,
                    color:
                        state.globalLowStockCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                    highlight: state.globalLowStockCount > 0,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Buscador y Categorías en una sola línea
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _SearchField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      hint: 'Buscar producto o SKU... (presiona /)',
                      onChanged: _onSearchChanged,
                      onClear: () {
                        _searchCtrl.clear();
                        cubit.setStockSearch('');
                      },
                      onScan: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'La función de escáner QR estará disponible pronto.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  if (state.categories.isNotEmpty) ...[
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              state.categories.map((cat) {
                                final isSelected =
                                    cat == state.stockCategoryFilter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _CategoryPill(
                                    label: cat,
                                    isSelected: isSelected,
                                    onTap: () => cubit.setStockCategory(cat),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ── Tabla de Datos de Alta Densidad ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.8),
                ),
                boxShadow: AppColors.cardShadow(opacity: 0.02),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child:
                    isLoading && state.stockItems.isEmpty
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                        : state.stockItems.isEmpty
                        ? const AppEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'Sin Resultados',
                          message: 'No hay productos con stock disponible',
                        )
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      AppColors.background.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    dataRowMinHeight: 64,
                                    dataRowMaxHeight: 64,
                                    columnSpacing: 20,
                                    showBottomBorder: true,
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'Producto',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'SKU / Categoría',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Costo / Venta',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Disponibilidad',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Acciones',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows:
                                        state.stockItems.map((item) {
                                          final isLowStock = item.isLowStock;
                                          return DataRow(
                                            color:
                                                WidgetStateProperty.resolveWith<
                                                  Color?
                                                >((Set<WidgetState> states) {
                                                  if (states.contains(
                                                    WidgetState.hovered,
                                                  )) {
                                                    return AppColors.primary
                                                        .withValues(
                                                          alpha: 0.03,
                                                        );
                                                  }
                                                  return null;
                                                }),
                                            cells: [
                                              DataCell(
                                                InkWell(
                                                  onTap:
                                                      () =>
                                                          _openProductDetail(item),
                                                  child: Row(
                                                    children: [
                                                      _buildAvatar(
                                                        item.imageUrl,
                                                        size: 42,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            item.productName,
                                                            style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 13.5,
                                                              color:
                                                                  AppColors
                                                                      .textPrimary,
                                                            ),
                                                          ),
                                                          if (item
                                                              .attrsText
                                                              .isNotEmpty)
                                                            Text(
                                                              item.attrsText,
                                                              style: const TextStyle(
                                                                fontSize: 11.5,
                                                                color:
                                                                    AppColors
                                                                        .textSecondary,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      item.sku?.isNotEmpty ==
                                                              true
                                                          ? item.sku!
                                                          : 'Sin SKU',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12.5,
                                                        fontFamily: 'monospace',
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                      ),
                                                    ),
                                                    Text(
                                                      item.category,
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        color:
                                                            AppColors
                                                                .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Costo: S/ ${item.unitCost.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        color:
                                                            AppColors
                                                                .textSecondary,
                                                        fontSize: 11.5,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Venta: S/ ${item.salePrice.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isLowStock
                                                            ? AppColors.warning
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                )
                                                            : AppColors.teal
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          isLowStock
                                                              ? AppColors
                                                                  .warning
                                                                  .withValues(
                                                                    alpha: 0.25,
                                                                  )
                                                              : AppColors.teal
                                                                  .withValues(
                                                                    alpha: 0.25,
                                                                  ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                      MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isLowStock
                                                            ? Icons
                                                                .warning_amber_rounded
                                                            : Icons
                                                                .check_circle_outline_rounded,
                                                        size: 13,
                                                        color:
                                                            isLowStock
                                                                ? AppColors
                                                                    .warning
                                                                : AppColors
                                                                    .tealDark,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${item.stock} uds.',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 12,
                                                          color:
                                                              isLowStock
                                                                  ? AppColors
                                                                      .warning
                                                                  : AppColors
                                                                      .tealDark,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Tooltip(
                                                      message: 'Ver en Kárdex',
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .receipt_long_rounded,
                                                          size: 17,
                                                        ),
                                                        color:
                                                            AppColors
                                                                .textSecondary,
                                                        onPressed:
                                                            () => context.push(
                                                              '/admin/kardex',
                                                            ),
                                                        splashRadius: 16,
                                                      ),
                                                    ),
                                                    Tooltip(
                                                      message:
                                                          'Ficha de Producto',
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons
                                                              .open_in_new_rounded,
                                                          size: 17,
                                                        ),
                                                        color:
                                                            AppColors.primary,
                                                        onPressed:
                                                            () =>
                                                                _openProductDetail(
                                                                  item,
                                                                ),
                                                        splashRadius: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ),
          ),
        ),

        // ── Paginación Inferior ──
        if (!isLoading && state.totalStockPages > 1)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: AdminPageBlocks(
              currentPage: state.currentStockPage,
              totalPages: state.totalStockPages,
              onPageChanged: (page) => cubit.setStockPage(page),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(String? imageUrl, {double size = 42}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                width: size,
                height: size,
                color: AppColors.background,
              ),
          errorWidget:
              (context, url, error) => Container(
                width: size,
                height: size,
                color: AppColors.background,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.border,
                ),
              ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.primary,
        size: 20,
      ),
    );
  }

  Widget _buildListContent(InventoryLoaded state, bool isLoading) {
    final cubit = context.read<InventoryCubit>();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Métricas ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _MetricCard(
                  label: 'Valor Inv.',
                  value: 'S/ ${state.globalTotalCost.toStringAsFixed(2)}',
                  icon: Icons.monetization_on_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Stock total',
                  value: '${state.globalTotalStock}',
                  icon: Icons.inventory_rounded,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Bajo stock',
                  value: '${state.globalLowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  color:
                      state.globalLowStockCount > 0
                          ? AppColors.warning
                          : AppColors.success,
                  highlight: state.globalLowStockCount > 0,
                ),
              ],
            ),
          ),
        ),

        // ── Filtros Sticky ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyStockFiltersDelegate(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    hint: 'Buscar producto o SKU... (presiona /)',
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchCtrl.clear();
                      cubit.setStockSearch('');
                    },
                    onScan: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La función de escáner QR estará disponible pronto.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  if (state.categories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            state.categories.map((cat) {
                              final isSelected =
                                  cat == state.stockCategoryFilter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _CategoryPill(
                                  label: cat,
                                  isSelected: isSelected,
                                  onTap: () => cubit.setStockCategory(cat),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Resumen Resultados ──
        if (!isLoading && state.stockItems.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Productos (${state.stockItems.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Página ${state.currentStockPage + 1} de ${state.totalStockPages}',
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

        // ── Lista Principal ──
        if (isLoading && state.stockItems.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _InventoryStockSkeleton()),
          )
        else if (state.stockItems.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Sin Resultados',
              message: 'No hay productos con stock disponible',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              state.totalStockPages > 1 ? 90 : 16,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final item = state.stockItems[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InventoryStockCard(
                    item: item,
                    onTap: () => _openProductDetail(item),
                  ),
                );
              }, childCount: state.stockItems.length),
            ),
          ),

        // ── Paginación ──
        if (!isLoading && state.totalStockPages > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AdminPageBlocks(
                currentPage: state.currentStockPage,
                totalPages: state.totalStockPages,
                onPageChanged: (page) => cubit.setStockPage(page),
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DELEGATES & WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StickyStockFiltersDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyStockFiltersDelegate({required this.child});

  @override
  double get minExtent => 110.0;
  @override
  double get maxExtent => 110.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyStockFiltersDelegate oldDelegate) => true;
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight ? color : AppColors.border,
            width: highlight ? 1.5 : 1,
          ),
          boxShadow: AppColors.cardShadow(opacity: 0.02),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: highlight ? color : AppColors.textPrimary,
                      height: 1.1,
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
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onScan;

  const _SearchField({
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
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
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: onClear,
              ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              color: AppColors.primary,
              onPressed: onScan,
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

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryStockSkeleton extends StatelessWidget {
  const _InventoryStockSkeleton();

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
                    AppShimmer(width: 90, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              const AppShimmer(width: 60, height: 22, borderRadius: 8),
            ],
          ),
        );
      },
    );
  }
}
