import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_product_quick_view_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_table.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'dart:async';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_palette.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_breakpoints.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_variant_panel.dart';

class InventoryStockTab extends StatefulWidget {
  final String? initialSearch;
  final String? initialStatusFilter;

  /// Se invoca con el SKU para saltar a la pestaña Lotes ya filtrada.
  final void Function(String search)? onViewLots;

  const InventoryStockTab({
    super.key,
    this.initialSearch,
    this.initialStatusFilter,
    this.onViewLots,
  });

  @override
  State<InventoryStockTab> createState() => _InventoryStockTabState();
}

class _InventoryStockTabState extends State<InventoryStockTab>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _searchCtrl;
  final _searchFocusNode = FocusNode();
  final _tabFocusNode = FocusNode();
  Timer? _debounce;
  InventoryStockItem? _selectedItem;

  /// true cuando hay espacio para lista + panel (>= InventoryBreakpoints.split).
  bool _splitLayout = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: widget.initialSearch?.trim() ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _tabFocusNode.requestFocus();
        if (widget.initialStatusFilter != null &&
            widget.initialStatusFilter!.trim().isNotEmpty) {
          final cubit = context.read<InventoryCubit>();
          final state = cubit.state;
          if (state is InventoryLoaded &&
              state.stockStatusFilter != widget.initialStatusFilter!.trim()) {
            cubit.setStockStatusFilter(widget.initialStatusFilter!.trim());
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _tabFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.read<InventoryCubit>().setStockSearch(value.trim());
      }
    });
  }

  void _onSearchSubmitted(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    context.read<InventoryCubit>().setStockSearch(value.trim());
  }

  void _openProductDetail(InventoryStockItem item) {
    context.push('/product/${item.productId}?variantId=${item.variantId}');
  }

  void _openKardex(InventoryStockItem item) {
    context.push(
      '/kardex?productId=${item.productId}&variantId=${item.variantId}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(item.attrsText)}',
    );
  }

  void _showQuickView(InventoryStockItem item, InventoryLoaded state) {
    InventoryProductQuickViewSheet.show(
      context,
      item: item,
      selectedWarehouseId: state.selectedWarehouseId,
      selectedWarehouseName: state.selectedWarehouseName,
    );
  }

  bool get _isInputFieldFocused =>
      FocusUtils.isInputFieldFocused(_searchFocusNode);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        final cubitState = context.read<InventoryCubit>().state;
        final loadedState =
            state is InventoryLoaded
                ? state
                : (cubitState is InventoryLoaded ? cubitState : null);

        if (loadedState == null) {
          if (state is InventoryError) {
            return Center(
              child: AppEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Error al cargar inventario',
                message: state.message,
                action: ElevatedButton.icon(
                  onPressed: () => context.read<InventoryCubit>().refreshAll(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Reintentar conexión'),
                ),
              ),
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final currentState = loadedState;

        return Focus(
          focusNode: _tabFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (_isInputFieldFocused) {
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  _searchFocusNode.unfocus();
                  _tabFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              }

              final isAlt = HardwareKeyboard.instance.isAltPressed;
              final isControl = HardwareKeyboard.instance.isControlPressed;
              final isMeta = HardwareKeyboard.instance.isMetaPressed;
              final isModifier = isAlt || isControl || isMeta;

              // ⌘K / Ctrl+K / Alt+K o '/' enfoca el buscador y selecciona el texto
              if ((isModifier && event.logicalKey == LogicalKeyboardKey.keyK) ||
                  event.logicalKey == LogicalKeyboardKey.slash) {
                _searchFocusNode.requestFocus();
                _searchCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _searchCtrl.text.length,
                );
                return KeyEventResult.handled;
              }

              // [B] o [Alt+B] -> Conmuta filtro de productos bajo stock
              if ((event.logicalKey == LogicalKeyboardKey.keyB &&
                      !isModifier) ||
                  (isAlt && event.logicalKey == LogicalKeyboardKey.keyB)) {
                final cubit = context.read<InventoryCubit>();
                final isLow =
                    currentState.stockStatusFilter == 'low_stock' ||
                    currentState.stockStatusFilter == 'bajo_stock';
                cubit.setStockStatusFilter(isLow ? 'all' : 'low_stock');
                AppSnackbar.show(
                  context,
                  message:
                      isLow
                          ? 'Mostrando todo el inventario'
                          : 'Filtrando: Solo productos bajo stock',
                  type: SnackbarType.info,
                );
                return KeyEventResult.handled;
              }

              // [T] o [Alt+T] -> Restablece filtro a Todos
              if ((event.logicalKey == LogicalKeyboardKey.keyT &&
                      !isModifier) ||
                  (isAlt && event.logicalKey == LogicalKeyboardKey.keyT)) {
                final cubit = context.read<InventoryCubit>();
                cubit.setStockStatusFilter('all');
                cubit.setStockCategory('Todos');
                AppSnackbar.show(
                  context,
                  message: 'Filtros restablecidos a "Todos"',
                  type: SnackbarType.info,
                );
                return KeyEventResult.handled;
              }

              // [R] refresca todo el inventario
              if (event.logicalKey == LogicalKeyboardKey.keyR && !isModifier) {
                context.read<InventoryCubit>().refreshAll();
                AppSnackbar.show(
                  context,
                  message: 'Actualizando catálogo de inventario...',
                  type: SnackbarType.info,
                );
                return KeyEventResult.handled;
              }

              // [Esc] limpia búsqueda, deselecciona o reenfoca
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                if (_selectedItem != null) {
                  setState(() => _selectedItem = null);
                  _tabFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (_searchCtrl.text.isNotEmpty) {
                  _searchCtrl.clear();
                  context.read<InventoryCubit>().setStockSearch('');
                  _tabFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (currentState.stockStatusFilter != 'all' ||
                    currentState.stockCategoryFilter != 'Todos') {
                  final cubit = context.read<InventoryCubit>();
                  cubit.setStockStatusFilter('all');
                  cubit.setStockCategory('Todos');
                  _tabFocusNode.requestFocus();
                  return KeyEventResult.handled;
                }
                _searchFocusNode.unfocus();
                _tabFocusNode.requestFocus();
                return KeyEventResult.handled;
              }

              // Flechas arriba y abajo para navegar productos/variantes
              final stockItems = currentState.stockItems;
              if (stockItems.isNotEmpty) {
                final currentIndex =
                    _selectedItem != null
                        ? stockItems.indexWhere(
                          (it) =>
                              (it.variantId.isNotEmpty &&
                                  it.variantId == _selectedItem!.variantId) ||
                              (it.productId == _selectedItem!.productId &&
                                  it.variantId == _selectedItem!.variantId),
                        )
                        : -1;

                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  final nextIndex = (currentIndex + 1).clamp(
                    0,
                    stockItems.length - 1,
                  );
                  setState(() => _selectedItem = stockItems[nextIndex]);
                  return KeyEventResult.handled;
                }

                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  final prevIndex = (currentIndex - 1).clamp(
                    0,
                    stockItems.length - 1,
                  );
                  setState(() => _selectedItem = stockItems[prevIndex]);
                  return KeyEventResult.handled;
                }

                // [Enter] o [NumpadEnter] abre la vista rápida / ficha de inspección
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  final item = _selectedItem ?? stockItems.first;
                  if (_splitLayout) {
                    if (_selectedItem == null) {
                      setState(() => _selectedItem = item);
                    } else {
                      _openProductDetail(item);
                    }
                  } else {
                    _showQuickView(item, currentState);
                  }
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >= InventoryBreakpoints.split;
              _splitLayout = isDesktop;

              if (isDesktop) {
                final list = _buildDesktopLayout(
                  currentState,
                  state is InventoryLoading,
                  cubit: context.read<InventoryCubit>(),
                );

                // Variante seleccionada con datos frescos (tras recargas)
                InventoryStockItem? selected = _selectedItem;
                if (selected != null) {
                  for (final it in currentState.stockItems) {
                    if (it.variantId == selected!.variantId &&
                        it.productId == selected.productId) {
                      selected = it;
                      break;
                    }
                  }
                }

                final sel = selected;
                final Widget? panel =
                    sel == null
                        ? null
                        : SizedBox(
                          width: InventoryBreakpoints.detailPaneWidth,
                          child: InventoryVariantPanel(
                            key: ValueKey(
                              '${sel.productId}-${sel.variantId}',
                            ),
                            item: sel,
                            warehouseName: currentState.selectedWarehouseName,
                            onClose: () => setState(() => _selectedItem = null),
                            onOpenDetail: () => _openProductDetail(sel),
                            onKardex: () => _openKardex(sel),
                            onViewLots:
                                widget.onViewLots == null
                                    ? null
                                    : () => widget.onViewLots!(sel.sku ?? sel.productName),
                          ),
                        );

                // Ancho suficiente para tabla (960) + panel (400): lo empuja.
                // Si no, el panel se superpone para no forzar scroll horizontal.
                if (constraints.maxWidth >= InventoryBreakpoints.wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: list),
                      if (panel != null) panel,
                    ],
                  );
                }
                return Stack(
                  children: [
                    Positioned.fill(child: list),
                    if (panel != null)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        child: Material(elevation: 8, child: panel),
                      ),
                  ],
                );
              }

              return _buildListContent(
                currentState,
                state is InventoryLoading,
                constraints: constraints,
              );
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
        Expanded(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Métricas y Filtros ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Métricas responsive con diseño alineado a Linear
                      Row(
                        children: [
                          _MetricCard(
                            label: 'Valor Total del Inv.',
                            value:
                                'S/ ${state.globalTotalCost.toStringAsFixed(2)}',
                            icon: Icons.monetization_on_rounded,
                            color: AppColors.primary,
                            tooltip: 'Restablecer vista a todo el catálogo',
                            onTap: () => cubit.setStockStatusFilter('all'),
                          ),
                          const SizedBox(width: 12),
                          _MetricCard(
                            label: 'Stock Total',
                            value: '${state.globalTotalStock} uds.',
                            icon: Icons.inventory_rounded,
                            color: AppColors.teal,
                            isSelected: state.stockStatusFilter == 'in_stock',
                            tooltip:
                                'Filtrar solo productos con stock disponible',
                            onTap:
                                () => cubit.setStockStatusFilter(
                                  state.stockStatusFilter == 'in_stock'
                                      ? 'all'
                                      : 'in_stock',
                                ),
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
                            isSelected: state.stockStatusFilter == 'low_stock',
                            tooltip:
                                'Clic para alternar filtro de bajo stock [B]',
                            onTap:
                                () => cubit.setStockStatusFilter(
                                  state.stockStatusFilter == 'low_stock'
                                      ? 'all'
                                      : 'low_stock',
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Toolbar Pro Unificado (Buscador, Estados Operativos, Categorías, Refresh)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: InventoryPalette.of(context).surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: InventoryPalette.of(context).border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x050F172A),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 7,
                              child: _SearchField(
                                controller: _searchCtrl,
                                focusNode: _searchFocusNode,
                                hint: 'Buscar producto o SKU... [ / ]',
                                onChanged: _onSearchChanged,
                                onSubmitted: _onSearchSubmitted,
                                isLoading: state.isSearchingStock,
                                onClear: () {
                                  if (_debounce?.isActive ?? false) {
                                    _debounce!.cancel();
                                  }
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
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 13,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    // ── Segmented Control de Estados Operativos ──
                                    _StatusPill(
                                      label: 'Todos',
                                      isSelected:
                                          state.stockStatusFilter == 'all',
                                      onTap:
                                          () =>
                                              cubit.setStockStatusFilter('all'),
                                    ),
                                    const SizedBox(width: 6),
                                    _StatusPill(
                                      label:
                                          'Bajo Stock (${state.globalLowStockCount})',
                                      icon: Icons.warning_amber_rounded,
                                      color: AppColors.warning,
                                      isSelected:
                                          state.stockStatusFilter ==
                                          'low_stock',
                                      onTap:
                                          () => cubit.setStockStatusFilter(
                                            state.stockStatusFilter ==
                                                    'low_stock'
                                                ? 'all'
                                                : 'low_stock',
                                          ),
                                    ),
                                    const SizedBox(width: 6),
                                    _StatusPill(
                                      label: 'Agotados',
                                      icon: Icons.highlight_off_rounded,
                                      color: AppColors.danger,
                                      isSelected:
                                          state.stockStatusFilter ==
                                          'out_of_stock',
                                      onTap:
                                          () => cubit.setStockStatusFilter(
                                            state.stockStatusFilter ==
                                                    'out_of_stock'
                                                ? 'all'
                                                : 'out_of_stock',
                                          ),
                                    ),
                                    if (state.categories.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      _CategoryFilterChip(
                                        categories: state.categories,
                                        selected: state.stockCategoryFilter,
                                        onSelected: cubit.setStockCategory,
                                      ),
                                    ],
                                    if (state.stockStatusFilter != 'all' ||
                                        state.stockCategoryFilter !=
                                            'Todos') ...[
                                      const SizedBox(width: 6),
                                      _ClearFilterPill(
                                        onTap: () {
                                          cubit.setStockStatusFilter('all');
                                          cubit.setStockCategory('Todos');
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tabla Pro de Inventario (AdminProTable) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      (isLoading || state.isSearchingStock) &&
                              state.stockItems.isEmpty
                          ? const SizedBox(
                            height: 300,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.teal,
                              ),
                            ),
                          )
                          : state.stockItems.isEmpty
                          ? SizedBox(
                            height: 320,
                            child: _buildEmptyState(state, cubit),
                          )
                          : InventoryStockTable(
                            items: state.stockItems,
                            selectedItem: _selectedItem,
                            isLoading: state.isSearchingStock,
                            onQuickView: (item) {
                              // Desktop: el panel derecho reemplaza al modal
                              setState(() => _selectedItem = item);
                            },
                            onOpenDetail: (item) {
                              setState(() => _selectedItem = item);
                              _openProductDetail(item);
                            },
                            onKardex: _openKardex,
                          ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),

        // ── Paginación Inferior ──
        if (!isLoading && state.totalStockPages > 1)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: AdminPageBlocks(
              currentPage: state.currentStockPage,
              totalPages: state.totalStockPages,
              totalItems:
                  (state.stockSearchText.isEmpty &&
                          state.stockCategoryFilter.isEmpty)
                      ? state.globalTotalVariants
                      : null,
              itemsPerPage: 15,
              itemName: 'variantes',
              onPageChanged: (page) => cubit.setStockPage(page),
            ),
          )
        else if (!isLoading && state.totalStockPages == 1)
          //Agregar espacio vacio para paginacion
          const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildEmptyState(InventoryLoaded state, InventoryCubit cubit) {
    final bool hasSearch = state.stockSearchText.trim().isNotEmpty;
    final bool hasCategory =
        state.stockCategoryFilter.isNotEmpty &&
        state.stockCategoryFilter != 'Todos';
    final bool hasStatus = state.stockStatusFilter != 'all';

    IconData icon = Icons.inventory_2_outlined;
    String title = 'Sin Resultados';
    String message = 'No hay productos con stock disponible para esta vista.';
    Widget? action;

    if (state.stockStatusFilter == 'low_stock') {
      icon = Icons.check_circle_outline_rounded;
      title = '¡Excelente! Sin Bajo Stock';
      message =
          'No se encontraron productos con existencias en o por debajo de su punto de reorden.';
      action = OutlinedButton.icon(
        onPressed: () => cubit.setStockStatusFilter('all'),
        icon: const Icon(Icons.inventory_2_outlined, size: 16),
        label: const Text('Ver todos los productos'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (state.stockStatusFilter == 'out_of_stock') {
      icon = Icons.check_circle_outline_rounded;
      title = 'Sin Productos Agotados';
      message =
          'Todos los productos con control de stock cuentan con existencias activas.';
      action = OutlinedButton.icon(
        onPressed: () => cubit.setStockStatusFilter('all'),
        icon: const Icon(Icons.inventory_2_outlined, size: 16),
        label: const Text('Ver todos los productos'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (hasSearch) {
      icon = Icons.search_off_rounded;
      title = 'Sin coincidencias de búsqueda';
      message =
          'No encontramos productos que coincidan con "${state.stockSearchText}".';
      action = OutlinedButton.icon(
        onPressed: () {
          _searchCtrl.clear();
          cubit.setStockSearch('');
        },
        icon: const Icon(Icons.clear_rounded, size: 16),
        label: const Text('Limpiar búsqueda'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (hasCategory) {
      icon = Icons.category_outlined;
      title = 'Categoría sin existencias';
      message =
          'No hay existencias registradas en la categoría "${state.stockCategoryFilter}".';
      action = OutlinedButton.icon(
        onPressed: () => cubit.setStockCategory('Todos'),
        icon: const Icon(Icons.layers_outlined, size: 16),
        label: const Text('Ver todas las categorías'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else if (hasStatus) {
      action = OutlinedButton.icon(
        onPressed: () => cubit.setStockStatusFilter('all'),
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Restablecer filtros'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return AppEmptyState(
      icon: icon,
      title: title,
      message: message,
      action: action,
    );
  }

  Widget _buildListContent(
    InventoryLoaded state,
    bool isLoading, {
    BoxConstraints? constraints,
  }) {
    final cubit = context.read<InventoryCubit>();
    final isTablet =
        constraints != null &&
        constraints.maxWidth >= InventoryBreakpoints.mobile &&
        constraints.maxWidth < InventoryBreakpoints.split;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Métricas Interactivas ──
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
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Stock total',
                  value: '${state.globalTotalStock}',
                  icon: Icons.inventory_rounded,
                  color: AppColors.teal,
                  isCompact: true,
                  isSelected: state.stockStatusFilter == 'in_stock',
                  tooltip: 'Filtrar con stock',
                  onTap:
                      () => cubit.setStockStatusFilter(
                        state.stockStatusFilter == 'in_stock'
                            ? 'all'
                            : 'in_stock',
                      ),
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
                  isCompact: true,
                  isSelected: state.stockStatusFilter == 'low_stock',
                  tooltip: 'Filtrar bajo stock [B]',
                  onTap:
                      () => cubit.setStockStatusFilter(
                        state.stockStatusFilter == 'low_stock'
                            ? 'all'
                            : 'low_stock',
                      ),
                ),
              ],
            ),
          ),
        ),

        // ── Filtros Sticky Móvil con Segmented Status ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyStockFiltersDelegate(
            height: 104.0,
            child: Container(
              color: InventoryPalette.of(context).background,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _searchCtrl,
                          focusNode: _searchFocusNode,
                          hint: 'Buscar producto o SKU...',
                          onChanged: _onSearchChanged,
                          onSubmitted: _onSearchSubmitted,
                          isLoading: state.isSearchingStock,
                          onClear: () {
                            if (_debounce?.isActive ?? false) {
                              _debounce!.cancel();
                            }
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusPill(
                          label: 'Todos',
                          isSelected: state.stockStatusFilter == 'all',
                          onTap: () => cubit.setStockStatusFilter('all'),
                        ),
                        const SizedBox(width: 6),
                        _StatusPill(
                          label: 'Bajo Stock (${state.globalLowStockCount})',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          isSelected: state.stockStatusFilter == 'low_stock',
                          onTap:
                              () => cubit.setStockStatusFilter(
                                state.stockStatusFilter == 'low_stock'
                                    ? 'all'
                                    : 'low_stock',
                              ),
                        ),
                        const SizedBox(width: 6),
                        _StatusPill(
                          label: 'Agotados',
                          icon: Icons.highlight_off_rounded,
                          color: AppColors.danger,
                          isSelected: state.stockStatusFilter == 'out_of_stock',
                          onTap:
                              () => cubit.setStockStatusFilter(
                                state.stockStatusFilter == 'out_of_stock'
                                    ? 'all'
                                    : 'out_of_stock',
                              ),
                        ),
                        if (state.categories.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _CategoryFilterChip(
                            categories: state.categories,
                            selected: state.stockCategoryFilter,
                            onSelected: cubit.setStockCategory,
                          ),
                        ],
                        if (state.stockStatusFilter != 'all' ||
                            (state.stockCategoryFilter.isNotEmpty &&
                                state.stockCategoryFilter != 'Todos')) ...[
                          const SizedBox(width: 6),
                          _ClearFilterPill(
                            onTap: () {
                              cubit.setStockStatusFilter('all');
                              cubit.setStockCategory('Todos');
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Indicador no destructivo de búsqueda ──
        if (state.isSearchingStock)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.primary,
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
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: InventoryPalette.of(context).textPrimary,
                    ),
                  ),
                  Text(
                    'Página ${state.currentStockPage + 1} de ${state.totalStockPages}',
                    style: TextStyle(
                      fontSize: 12,
                      color: InventoryPalette.of(context).textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Lista Principal ──
        if ((isLoading || state.isSearchingStock) && state.stockItems.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _InventoryStockSkeleton()),
          )
        else if (state.stockItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(state, cubit),
          )
        else if (isTablet)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              state.totalStockPages > 1 ? 90 : 16,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 440,
                mainAxisExtent: 220,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final item = state.stockItems[i];
                final isItemSelected =
                    _selectedItem != null &&
                    ((_selectedItem!.variantId.isNotEmpty &&
                            _selectedItem!.variantId == item.variantId) ||
                        (_selectedItem!.productId == item.productId &&
                            _selectedItem!.variantId == item.variantId));
                return RepaintBoundary(
                  child: InventoryStockCard(
                    item: item,
                    isSelected: isItemSelected,
                    onTap: () {
                      setState(() => _selectedItem = item);
                      _showQuickView(item, state);
                    },
                  ),
                );
              }, childCount: state.stockItems.length),
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
                final isItemSelected =
                    _selectedItem != null &&
                    ((_selectedItem!.variantId.isNotEmpty &&
                            _selectedItem!.variantId == item.variantId) ||
                        (_selectedItem!.productId == item.productId &&
                            _selectedItem!.variantId == item.variantId));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RepaintBoundary(
                    child: InventoryStockCard(
                      item: item,
                      isSelected: isItemSelected,
                      onTap: () {
                        setState(() => _selectedItem = item);
                        _showQuickView(item, state);
                      },
                    ),
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
                totalItems:
                    (state.stockSearchText.isEmpty &&
                            state.stockCategoryFilter.isEmpty)
                        ? state.globalTotalVariants
                        : null,
                itemsPerPage: 15,
                itemName: 'variantes',
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
  final double height;
  final Widget child;
  _StickyStockFiltersDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyStockFiltersDelegate oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}

class _MetricCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;
  final bool isCompact;
  final bool isSelected;
  final String? tooltip;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
    this.isCompact = false,
    this.isSelected = false,
    this.tooltip,
    this.onTap,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        widget.isSelected
            ? widget.color
            : (_isHovered
                ? widget.color.withValues(alpha: 0.5)
                : (widget.highlight ? widget.color : InventoryPalette.of(context).border));
    final effectiveBg =
        widget.isSelected
            ? widget.color.withValues(alpha: 0.08)
            : (_isHovered
                ? widget.color.withValues(alpha: 0.03)
                : InventoryPalette.of(context).surface);

    final cardWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 8 : 14,
        vertical: widget.isCompact ? 9 : 11,
      ),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: effectiveBorder,
          width: widget.isSelected ? 2 : (widget.highlight ? 1.5 : 1),
        ),
        boxShadow:
            widget.isSelected
                ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : AppColors.cardShadow(opacity: _isHovered ? 0.05 : 0.02),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(widget.isCompact ? 5 : 7),
            decoration: BoxDecoration(
              color:
                  widget.isSelected
                      ? widget.color
                      : widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: widget.isCompact ? 14 : 16,
              color: widget.isSelected ? Colors.white : widget.color,
            ),
          ),
          SizedBox(width: widget.isCompact ? 6 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: widget.isCompact ? 10 : 11,
                          color: InventoryPalette.of(context).textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVO',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: widget.isCompact ? 13 : 15,
                      fontWeight: FontWeight.w900,
                      color:
                          (widget.highlight || widget.isSelected)
                              ? widget.color
                              : InventoryPalette.of(context).textPrimary,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget interactive = cardWidget;
    if (widget.onTap != null) {
      interactive = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: cardWidget,
        ),
      );
    }

    if (widget.tooltip != null) {
      interactive = Tooltip(message: widget.tooltip!, child: interactive);
    }

    return Expanded(child: interactive);
  }
}

class _StatusPill extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _StatusPill({
    required this.label,
    this.icon,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppColors.primary;
    final bg =
        widget.isSelected
            ? activeColor
            : (_isHovered
                ? activeColor.withValues(alpha: 0.08)
                : InventoryPalette.of(context).surface);
    final border =
        widget.isSelected
            ? activeColor
            : (_isHovered
                ? activeColor.withValues(alpha: 0.3)
                : InventoryPalette.of(context).border);
    final textCol =
        widget.isSelected
            ? Colors.white
            : (_isHovered ? activeColor : InventoryPalette.of(context).textPrimary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: border,
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow:
                  widget.isSelected
                      ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 13,
                    color: widget.isSelected ? Colors.white : activeColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: textCol,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearFilterPill extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearFilterPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.close_rounded, size: 12, color: AppColors.danger),
              SizedBox(width: 3),
              Text(
                'Limpiar',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
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
  final VoidCallback onScan;
  final bool isLoading;

  const _SearchField({
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    required this.onClear,
    required this.onScan,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: InventoryPalette.of(context).textPrimary,
        ),
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: InventoryPalette.of(context).textMuted,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: AppColors.teal,
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
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, val, _) {
                  if (val.text.isNotEmpty && !isLoading) {
                    return IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      color: InventoryPalette.of(context).textMuted,
                      onPressed: onClear,
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: InventoryPalette.of(context).subtle,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: InventoryPalette.of(context).border),
                      ),
                      child: Text(
                        '/',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: InventoryPalette.of(context).textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                color: AppColors.teal,
                tooltip: 'Escanear QR',
                onPressed: onScan,
              ),
            ],
          ),
          filled: true,
          fillColor: InventoryPalette.of(context).background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: InventoryPalette.of(context).border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: InventoryPalette.of(context).border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
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
            color: InventoryPalette.of(context).surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: InventoryPalette.of(context).border),
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

/// Un solo chip "Categoría" que abre un menú, en vez de una fila de 10+ chips.
class _CategoryFilterChip extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryFilterChip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  bool get _active => selected.isNotEmpty && selected != 'Todos';

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filtrar por categoría',
      offset: const Offset(0, 40),
      constraints: const BoxConstraints(maxHeight: 360, minWidth: 200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: InventoryPalette.of(context).border),
      ),
      onSelected: onSelected,
      itemBuilder:
          (_) => [
            for (final c in categories)
              PopupMenuItem<String>(
                value: c,
                child: Row(
                  children: [
                    Icon(
                      c == selected
                          ? Icons.check_rounded
                          : Icons.folder_outlined,
                      size: 16,
                      color:
                          c == selected
                              ? AppColors.primary
                              : InventoryPalette.of(context).textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c == 'Todos' ? 'Todas las categorías' : c,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              c == selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _active ? AppColors.primary : InventoryPalette.of(context).surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _active ? AppColors.primary : InventoryPalette.of(context).border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 14,
              color: _active ? Colors.white : InventoryPalette.of(context).textSecondary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                _active ? selected : 'Categoría',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: _active ? FontWeight.w700 : FontWeight.w600,
                  color: _active ? Colors.white : InventoryPalette.of(context).textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _active ? Colors.white : InventoryPalette.of(context).textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}