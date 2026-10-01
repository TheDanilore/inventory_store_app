import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_product_quick_view_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'dart:async';

class InventoryStockTab extends StatefulWidget {
  final String? initialSearch;

  const InventoryStockTab({super.key, this.initialSearch});

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

              // [R] refresca todo el inventario
              if (event.logicalKey == LogicalKeyboardKey.keyR) {
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
                _searchFocusNode.unfocus();
                _tabFocusNode.requestFocus();
                return KeyEventResult.handled;
              }

              // Flechas arriba y abajo para navegar productos/variantes
              final stockItems = currentState.stockItems;
              if (stockItems.isNotEmpty) {
                final currentIndex = _selectedItem != null
                    ? stockItems.indexWhere((it) =>
                        (it.variantId.isNotEmpty &&
                            it.variantId == _selectedItem!.variantId) ||
                        (it.productId == _selectedItem!.productId &&
                            it.variantId == _selectedItem!.variantId))
                    : -1;

                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  final nextIndex =
                      (currentIndex + 1).clamp(0, stockItems.length - 1);
                  setState(() => _selectedItem = stockItems[nextIndex]);
                  return KeyEventResult.handled;
                }

                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  final prevIndex =
                      (currentIndex - 1).clamp(0, stockItems.length - 1);
                  setState(() => _selectedItem = stockItems[prevIndex]);
                  return KeyEventResult.handled;
                }

                // [Enter] o [NumpadEnter] abre la vista rápida / ficha de inspección
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  final item = _selectedItem ?? stockItems.first;
                  _showQuickView(item, currentState);
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
                      // Toolbar Pro Unificado (Buscador, Categorías, Refresh)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              flex: 4,
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
                            if (state.categories.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 6,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children:
                                        state.categories.map((cat) {
                                          final isSelected =
                                              cat == state.stockCategoryFilter;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: _CategoryPill(
                                              label: cat,
                                              isSelected: isSelected,
                                              onTap:
                                                  () =>
                                                      cubit.setStockCategory(cat),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 20,
                              ),
                              color: AppColors.textSecondary,
                              tooltip: 'Refrescar inventario [R]',
                              onPressed: () => cubit.refreshAll(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Encabezado de Navegación y Contador (Estilo Pedidos) ────
              if (!isLoading && state.stockItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          '${state.stockItems.length} ${state.stockItems.length == 1 ? "producto" : "productos"} en esta página',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            '↑ ↓ navegar',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Pág. ${state.currentStockPage + 1} / ${state.totalStockPages}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Tabla Pro de Inventario (Estilo OrdersTableView) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x050F172A),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (state.isSearchingStock)
                          const SizedBox(
                            height: 2,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: AppColors.teal,
                            ),
                          ),
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
                            ? const SizedBox(
                              height: 300,
                              child: AppEmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: 'Sin Resultados',
                                message:
                                    'No hay productos con stock disponible',
                              ),
                            )
                            : LayoutBuilder(
                              builder: (context, constraints) {
                                const minTableWidth = 920.0;
                                final tableWidth =
                                    constraints.maxWidth < minTableWidth
                                        ? minTableWidth
                                        : constraints.maxWidth;

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // --- Encabezado Fijo de Tabla ---
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 12,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: AppColors.background,
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Color(0xFFE2E8F0),
                                              ),
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: Text(
                                                  'PRODUCTO / VARIANTE',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textSecondary,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 170,
                                                child: Text(
                                                  'SKU / CATEGORÍA',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textSecondary,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 160,
                                                child: Text(
                                                  'COSTO / VENTA',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textSecondary,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 150,
                                                child: Text(
                                                  'DISPONIBILIDAD',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textSecondary,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 130,
                                                child: Text(
                                                  'ACCIONES',
                                                  textAlign: TextAlign.end,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textSecondary,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // --- Filas de Datos ---
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: state.stockItems.length,
                                          separatorBuilder:
                                              (_, _) => const Divider(
                                                height: 1,
                                                thickness: 1,
                                                color: Color(0xFFE2E8F0),
                                              ),
                                          itemBuilder: (context, index) {
                                            final item = state.stockItems[index];
                                            final isItemSelected = _selectedItem != null &&
                                                ((_selectedItem!.variantId.isNotEmpty &&
                                                        _selectedItem!.variantId == item.variantId) ||
                                                    (_selectedItem!.productId == item.productId &&
                                                        _selectedItem!.variantId == item.variantId));
                                            return _InventoryStockTableRow(
                                              key: ValueKey(
                                                item.variantId.isNotEmpty
                                                    ? item.variantId
                                                    : item.productId,
                                              ),
                                              item: item,
                                              isSelected: isItemSelected,
                                              onQuickView: () {
                                                setState(() => _selectedItem = item);
                                                _showQuickView(item, state);
                                              },
                                              onOpenDetail: () {
                                                setState(() => _selectedItem = item);
                                                _openProductDetail(item);
                                              },
                                              onKardex: () => context.push(
                                                '/kardex?productId=${item.productId}&variantId=${item.variantId}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(item.attrsText)}',
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
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
              itemsPerPage: 24,
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

  static Widget buildAvatar(String? imageUrl, {double size = 42}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: 120,
          memCacheHeight: 120,
          maxWidthDiskCache: 250,
          maxHeightDiskCache: 250,
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

  Widget _buildListContent(
    InventoryLoaded state,
    bool isLoading, {
    BoxConstraints? constraints,
  }) {
    final cubit = context.read<InventoryCubit>();
    final isTablet = constraints != null &&
        constraints.maxWidth >= 600 &&
        constraints.maxWidth < 900;
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
                  isCompact: true,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Stock total',
                  value: '${state.globalTotalStock}',
                  icon: Icons.inventory_rounded,
                  color: AppColors.teal,
                  isCompact: true,
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
                ),
              ],
            ),
          ),
        ),

        // ── Filtros Sticky ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyStockFiltersDelegate(
            height: state.categories.isNotEmpty ? 116.0 : 68.0,
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    hint: 'Buscar producto o SKU...',
                    onChanged: _onSearchChanged,
                    onSubmitted: _onSearchSubmitted,
                    isLoading: state.isSearchingStock,
                    onClear: () {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
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
        if ((isLoading || state.isSearchingStock) && state.stockItems.isEmpty)
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
                final isItemSelected = _selectedItem != null &&
                    ((_selectedItem!.variantId.isNotEmpty &&
                            _selectedItem!.variantId == item.variantId) ||
                        (_selectedItem!.productId == item.productId &&
                            _selectedItem!.variantId == item.variantId));
                return InventoryStockCard(
                  item: item,
                  isSelected: isItemSelected,
                  onTap: () {
                    setState(() => _selectedItem = item);
                    _showQuickView(item, state);
                  },
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
                final isItemSelected = _selectedItem != null &&
                    ((_selectedItem!.variantId.isNotEmpty &&
                            _selectedItem!.variantId == item.variantId) ||
                        (_selectedItem!.productId == item.productId &&
                            _selectedItem!.variantId == item.variantId));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                itemsPerPage: 24,
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;
  final bool isCompact;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 14,
          vertical: isCompact ? 9 : 11,
        ),
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
              padding: EdgeInsets.all(isCompact ? 5 : 7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: isCompact ? 14 : 16, color: color),
            ),
            SizedBox(width: isCompact ? 6 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isCompact ? 10 : 11,
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
                      fontSize: isCompact ? 13 : 15,
                      fontWeight: FontWeight.w900,
                      color: highlight ? color : AppColors.textPrimary,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
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
                      color: AppColors.textMuted,
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        '/',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
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
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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

// ─────────────────────────────────────────────────────────────────────────────
// FILA PRO DE INVENTARIO CON HOVER SUAVE
// ─────────────────────────────────────────────────────────────────────────────

class _InventoryStockTableRow extends StatefulWidget {
  final InventoryStockItem item;
  final bool isSelected;
  final VoidCallback onQuickView;
  final VoidCallback onOpenDetail;
  final VoidCallback onKardex;

  const _InventoryStockTableRow({
    super.key,
    required this.item,
    this.isSelected = false,
    required this.onQuickView,
    required this.onOpenDetail,
    required this.onKardex,
  });

  @override
  State<_InventoryStockTableRow> createState() =>
      _InventoryStockTableRowState();
}

class _InventoryStockTableRowState extends State<_InventoryStockTableRow> {
  bool _isHovered = false;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isOut = item.stock <= 0;
    final isLow = item.isLowStock;

    final Color badgeBg =
        isOut
            ? AppColors.danger.withValues(alpha: 0.08)
            : (isLow
                ? AppColors.warning.withValues(alpha: 0.1)
                : AppColors.teal.withValues(alpha: 0.1));
    final Color badgeBorder =
        isOut
            ? AppColors.danger.withValues(alpha: 0.25)
            : (isLow
                ? AppColors.warning.withValues(alpha: 0.25)
                : AppColors.teal.withValues(alpha: 0.25));
    final Color badgeColor =
        isOut
            ? AppColors.danger
            : (isLow ? AppColors.warningDark : AppColors.tealDark);
    final IconData badgeIcon =
        isOut
            ? Icons.highlight_off_rounded
            : (isLow
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onQuickView,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.teal.withValues(alpha: 0.08)
                : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
            border: Border(
              left: BorderSide(
                color: widget.isSelected
                    ? AppColors.teal
                    : (_isHovered
                        ? AppColors.teal.withValues(alpha: 0.6)
                        : Colors.transparent),
                width: 3.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              // 1. Producto (Avatar + Nombre + Variante)
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    _InventoryStockTabState.buildAvatar(item.imageUrl, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.attrsText.trim().isNotEmpty &&
                              item.attrsText.trim() != 'Única' &&
                              item.attrsText.trim().toLowerCase() !=
                                  'variante estándar')
                            Text(
                              item.attrsText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. SKU / Categoría
              SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.sku?.isNotEmpty == true)
                      InkWell(
                        onTap: () => _copyToClipboard(context, item.sku!, 'SKU'),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            item.sku!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Sin SKU',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      item.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 3. Costo / Venta
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Costo: S/ ${item.unitCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Venta: S/ ${item.salePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Disponibilidad (Badge pill)
              SizedBox(
                width: 150,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 12, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          '${item.stock} uds.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Acciones
              SizedBox(
                width: 130,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Ficha Rápida y Variantes',
                      child: IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 17),
                        color: AppColors.teal,
                        onPressed: widget.onQuickView,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Tooltip(
                      message: 'Ver en Kárdex',
                      child: IconButton(
                        icon: const Icon(Icons.receipt_long_rounded, size: 17),
                        color: AppColors.textSecondary,
                        onPressed: widget.onKardex,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    Tooltip(
                      message: 'Ficha Completa de Producto',
                      child: IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 17),
                        color: AppColors.textSecondary,
                        onPressed: widget.onOpenDetail,
                        splashRadius: 16,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
