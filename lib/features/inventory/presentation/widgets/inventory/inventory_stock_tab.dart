import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/data/cache/inventory_lru_cache.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_breakpoints.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_palette.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_product_quick_view_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_qr_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_table.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/stock_tab/inventory_stock_cards_grid.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/stock_tab/inventory_stock_metrics_bar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/stock_tab/inventory_stock_skeleton.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/stock_tab/inventory_stock_toolbar_wrapper.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class InventoryStockTab extends StatefulWidget {
  final String? initialSearch;
  final String? initialStatusFilter;

  const InventoryStockTab({
    super.key,
    this.initialSearch,
    this.initialStatusFilter,
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

  bool _isTableView = true;

  final StringBuffer _barcodeBuffer = StringBuffer();
  DateTime _lastBarcodeKeystrokeTime = DateTime.fromMillisecondsSinceEpoch(0);

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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        context.read<InventoryCubit>().setStockSearch(value.trim());
      }
    });
  }

  void _onSearchSubmitted(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    context.read<InventoryCubit>().setStockSearch(value.trim());
  }

  Future<void> _openCameraScanner() async {
    final res = await PosCameraScannerDialog.show(
      context,
      title: 'Inventario: Escaneo de Producto',
    );
    if (!mounted || res == null) return;
    _applyScanResult(res);
  }

  Future<void> _processScannedBarcode(String rawCode) async {
    final res = await PosBarcodeScannerService.resolveCode(rawCode);
    if (!mounted) return;
    if (res != null) {
      _applyScanResult(res);
    } else {
      _searchCtrl.text = rawCode;
      context.read<InventoryCubit>().setStockSearch(rawCode);
      AppSnackbar.show(
        context,
        message: 'Buscando código escaneado: "$rawCode"',
        type: SnackbarType.info,
      );
    }
  }

  void _applyScanResult(PosScanResult res) {
    final targetCode =
        res.variant?.sku ?? res.product.defaultVariant?.sku ?? res.product.name;
    _searchCtrl.text = targetCode;
    context.read<InventoryCubit>().setStockSearch(targetCode);
    AppFeedbackService.lightImpact();
    AppSnackbar.show(
      context,
      message:
          'Producto detectado: ${res.product.name} ${res.variant?.shortLabel ?? ''}',
      type: SnackbarType.success,
    );
  }

  void _openProductDetail(InventoryStockItem item) {
    context.go(
      Uri(
        path: '/product/${item.productId}',
        queryParameters: {'variantId': item.variantId},
      ).toString(),
    );
  }

  void _openKardex(InventoryStockItem item) {
    context.go(
      Uri(
        path: '/kardex',
        queryParameters: {
          'productId': item.productId,
          'variantId': item.variantId,
          'productName': item.productName,
          'variantName': item.attrsText,
        },
      ).toString(),
    );
  }

  void _showQr(InventoryStockItem item) {
    InventoryQrSheet.show(
      context,
      productId: item.productId,
      variantId: item.variantId,
      productName: item.productName,
      variantName: item.attrsText,
      sku: item.sku,
      barcode: item.barcode,
    );
  }

  void _openStockEntry(InventoryStockItem item, InventoryLoaded state) {
    context.push(
      '/inventory-entries/form',
      extra: {
        'prefillWarehouseId': state.selectedWarehouseId,
        'prefillItems': [
          InventoryEntryItemEntity(
            productId: item.productId,
            productName: item.productName,
            variantId: item.variantId,
            variantLabel: item.attrsText,
            imageUrl: item.imageUrl,
            usesBatches: item.usesBatches,
            quantity: 1,
            unitCost: item.unitCost,
            batchNumber: item.usesBatches ? '' : 'DEFAULT',
          ),
        ],
      },
    );
  }

  void _openStockExit(InventoryStockItem item, InventoryLoaded state) {
    context.push(
      '/inventory-exits/form',
      extra: {
        'warehouseId': state.selectedWarehouseId,
        'prefillVariantId': item.variantId,
        'prefillProductId': item.productId,
        'prefillProductName': item.productName,
        'prefillVariantName': item.attrsText,
        'reason': 'AJUSTE',
      },
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

  AdminTablePaginationConfig _buildPaginationConfig(
    InventoryLoaded state,
    InventoryCubit cubit,
  ) {
    const pageSize = 15;
    final categoryActive =
        state.stockCategoryFilter.isNotEmpty &&
        state.stockCategoryFilter != 'Todos';
    final hasWarehouse =
        state.selectedWarehouseId != null &&
        state.selectedWarehouseId!.isNotEmpty;
    final isUnfiltered =
        state.stockSearchText.isEmpty &&
        !categoryActive &&
        state.stockStatusFilter == 'all' &&
        !hasWarehouse;

    return AdminTablePaginationConfig(
      currentPage: state.currentStockPage + 1,
      pageSize: pageSize,
      totalItems: isUnfiltered ? state.globalTotalVariants : null,
      totalPagesOverride: state.totalStockPages,
      pageSizeOptions: const [pageSize],
      onPageChanged: (page) => cubit.setStockPage(page - 1),
      onPageSizeChanged: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen:
          (prev, curr) =>
              prev.runtimeType != curr.runtimeType ||
              (prev is InventoryLoaded &&
                  curr is InventoryLoaded &&
                  (prev.stockItems != curr.stockItems ||
                      prev.currentStockPage != curr.currentStockPage ||
                      prev.totalStockPages != curr.totalStockPages ||
                      prev.isSearchingStock != curr.isSearchingStock ||
                      prev.selectedWarehouseId != curr.selectedWarehouseId)),
      builder: (context, state) {
        final cubitState = context.read<InventoryCubit>().state;
        final loadedState =
            state is InventoryLoaded
                ? state
                : (cubitState is InventoryLoaded ? cubitState : null);

        // ZERO-SHIMMER: Si no hay loadedState pero hay caché LRU, esperar Frame 0
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
          if (InventoryLruCache.instance.hasAnyStock) {
            return const SizedBox.shrink();
          }
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final currentState = loadedState;

        return Focus(
          focusNode: _tabFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) => _handleKeyEvent(event, currentState),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >= InventoryBreakpoints.split;
              final isLoading = state is InventoryLoading;

              if (isDesktop) {
                return _buildDesktopLayout(currentState, isLoading);
              }
              return _buildMobileTabletLayout(
                currentState,
                isLoading,
                constraints,
              );
            },
          ),
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event, InventoryLoaded currentState) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isModifier = isAlt || isControl || isMeta;

    final char = event.character;
    final now = DateTime.now();
    final diffMs = now.difference(_lastBarcodeKeystrokeTime).inMilliseconds;
    _lastBarcodeKeystrokeTime = now;

    if (!isModifier) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.length >= 3 && diffMs < 150) {
          final scannedCode = _barcodeBuffer.toString().trim();
          _barcodeBuffer.clear();
          if (scannedCode.isNotEmpty) {
            _processScannedBarcode(scannedCode);
            return KeyEventResult.handled;
          }
        }
        _barcodeBuffer.clear();
      } else if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
        if (diffMs > 250) _barcodeBuffer.clear();
        _barcodeBuffer.write(char);
      }
    } else {
      _barcodeBuffer.clear();
    }

    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        _tabFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if ((isModifier && event.logicalKey == LogicalKeyboardKey.keyK) ||
        event.logicalKey == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    if ((event.logicalKey == LogicalKeyboardKey.keyB && !isModifier) ||
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

    if ((event.logicalKey == LogicalKeyboardKey.keyT && !isModifier) ||
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

    if (event.logicalKey == LogicalKeyboardKey.keyV && !isModifier) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyR && !isModifier) {
      context.read<InventoryCubit>().refreshAll();
      AppSnackbar.show(
        context,
        message: 'Actualizando catálogo de inventario...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

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
        final nextIndex = (currentIndex + 1).clamp(0, stockItems.length - 1);
        setState(() => _selectedItem = stockItems[nextIndex]);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, stockItems.length - 1);
        setState(() => _selectedItem = stockItems[prevIndex]);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final item = _selectedItem ?? stockItems.first;
        _showQuickView(item, currentState);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildDesktopLayout(InventoryLoaded state, bool isLoading) {
    final cubit = context.read<InventoryCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const RepaintBoundary(child: InventoryStockMetricsBar()),
                      const SizedBox(height: 14),
                      RepaintBoundary(
                        child: InventoryStockToolbarWrapper(
                          searchController: _searchCtrl,
                          searchFocusNode: _searchFocusNode,
                          onSearchChanged: _onSearchChanged,
                          onSearchSubmitted: _onSearchSubmitted,
                          onClearSearch: () {
                            _debounce?.cancel();
                            _searchCtrl.clear();
                            cubit.setStockSearch('');
                          },
                          onScanBarcode: _openCameraScanner,
                          isTableView: _isTableView,
                          onToggleTableView:
                              (val) => setState(() => _isTableView = val),
                          isDesktop: true,
                          isTablet: false,
                          margin: EdgeInsets.zero,
                        ),
                      ),
                      if (state.isSearchingStock)
                        const SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if ((isLoading || state.isSearchingStock) &&
                  state.stockItems.isEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 260,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    ),
                  ),
                )
              else if (state.stockItems.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: _buildEmptyState(state, cubit),
                  ),
                )
              else if (!_isTableView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: InventoryStockCardsSliverGrid(
                    items: state.stockItems,
                    selectedItem: _selectedItem,
                    onQuickView: (it) {
                      setState(() => _selectedItem = it);
                      _showQuickView(it, state);
                    },
                    onStockEntry: (it) => _openStockEntry(it, state),
                    onStockExit: (it) => _openStockExit(it, state),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InventoryStockTable(
                      items: state.stockItems,
                      selectedItem: _selectedItem,
                      isLoading: state.isSearchingStock,
                      paginationConfig: _buildPaginationConfig(state, cubit),
                      onQuickView: (item) {
                        setState(() => _selectedItem = item);
                        _showQuickView(item, state);
                      },
                      onOpenDetail: (item) {
                        setState(() => _selectedItem = item);
                        _openProductDetail(item);
                      },
                      onKardex: _openKardex,
                      onShowQr: _showQr,
                      onStockEntry: (it) => _openStockEntry(it, state),
                      onStockExit: (it) => _openStockExit(it, state),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
        if (!_isTableView && !isLoading && state.totalStockPages > 1)
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
          ),
      ],
    );
  }

  Widget _buildMobileTabletLayout(
    InventoryLoaded state,
    bool isLoading,
    BoxConstraints constraints,
  ) {
    final cubit = context.read<InventoryCubit>();
    final isTablet = constraints.maxWidth >= InventoryBreakpoints.mobile;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: RepaintBoundary(
              child: InventoryStockMetricsBar(isCompact: true),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyStockFiltersDelegate(
            height: isTablet ? 134.0 : 68.0,
            child: Container(
              color: InventoryPalette.of(context).background,
              alignment: Alignment.topCenter,
              child: InventoryStockToolbarWrapper(
                searchController: _searchCtrl,
                searchFocusNode: _searchFocusNode,
                onSearchChanged: _onSearchChanged,
                onSearchSubmitted: _onSearchSubmitted,
                onClearSearch: () {
                  _debounce?.cancel();
                  _searchCtrl.clear();
                  cubit.setStockSearch('');
                },
                onScanBarcode: _openCameraScanner,
                isTableView: false,
                onToggleTableView: (_) {},
                isDesktop: false,
                isTablet: isTablet,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              ),
            ),
          ),
        ),
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
        if ((isLoading || state.isSearchingStock) && state.stockItems.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: InventoryStockSkeleton()),
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
            sliver: InventoryStockCardsSliverGrid(
              items: state.stockItems,
              selectedItem: _selectedItem,
              onQuickView: (it) {
                setState(() => _selectedItem = it);
                _showQuickView(it, state);
              },
              onStockEntry: (it) => _openStockEntry(it, state),
              onStockExit: (it) => _openStockExit(it, state),
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
                      onStockEntry: () => _openStockEntry(item, state),
                      onStockExit: () => _openStockExit(item, state),
                    ),
                  ),
                );
              }, childCount: state.stockItems.length),
            ),
          ),
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
}

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
