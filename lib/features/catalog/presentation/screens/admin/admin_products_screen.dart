import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/utils/hardware_barcode_gun_detector.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/dialogs/adaptive_destructive_dialog.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/desktop/products_desktop_table.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/products_metrics_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/products_mobile_sliver_list.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/products_toolbar_wrapper.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/quick_view/product_quick_view_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_qr_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla Principal de CatÃ¡logo e Inventario de Productos para Administradores.
/// DiseÃ±o camaleÃ³nico de alta densidad para Desktop, eficiencia hÃ­brida para Tablet
/// y ergonomÃ­a estilo Apple HIG para MÃ³vil.
///
/// Optimizado con Frame-0 Zero-Shimmer (SWR), reciclaje de memoria O(1) con slivers virtualizados,
/// y desacoplamiento de rebuilds mediante widgets atÃ³micos.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final FocusNode _screenFocusNode;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);
  final _gunDetector = HardwareBarcodeGunDetector();
  bool _isTableView = true;

  // SelecciÃ³n mÃºltiple aislada mediante ValueNotifier (previene re-renders globales)
  final ValueNotifier<Set<String>> _selectedProductIdsNotifier =
      ValueNotifier<Set<String>>({});

  @override
  void initState() {
    super.initState();
    _screenFocusNode = FocusNode();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        final cubit = context.read<AdminCatalogCubit>();
        _searchCtrl.text = cubit.state.searchTerm;
        if (cubit.state.products.isEmpty) {
          cubit.loadInitialData();
        }
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.offset > 20 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 20 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _selectedProductIdsNotifier.dispose();
    super.dispose();
  }

  // â”€â”€ REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool get _isInputFieldFocused =>
      FocusUtils.isInputFieldFocused(_searchFocusNode);

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final barcode = _gunDetector.onKeyEvent(event);
    if (barcode != null) {
      _searchCtrl.text = barcode;
      context.read<AdminCatalogCubit>().submitSearch(barcode, force: true);
      AppSnackbar.show(
        context,
        message: 'Lector detectÃ³ cÃ³digo: $barcode',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo editable, aislar atajos globales
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Atajo [/] -> Enfocar buscador con selecciÃ³n total
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nuevo Producto
    if (key == LogicalKeyboardKey.keyN) {
      context.go('/products/product-form');
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar catÃ¡logo
    if (key == LogicalKeyboardKey.keyR) {
      context.read<AdminCatalogCubit>().refreshProducts();
      AppSnackbar.show(
        context,
        message: 'CatÃ¡logo de productos actualizado',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla Pro vs Tarjetas)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajo [Escape] -> Limpiar bÃºsqueda o selecciÃ³n
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedProductIdsNotifier.value.isNotEmpty) {
        _clearSelection();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<AdminCatalogCubit>().setSearchTerm('');
        return KeyEventResult.handled;
      }
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _toggleProductSelected(String id, bool isSelected) {
    final current = Set<String>.from(_selectedProductIdsNotifier.value);
    if (isSelected) {
      current.add(id);
    } else {
      current.remove(id);
    }
    _selectedProductIdsNotifier.value = current;
  }

  void _selectAllPage(List<ProductEntity> pageProducts, bool selectAll) {
    final current = Set<String>.from(_selectedProductIdsNotifier.value);
    if (selectAll) {
      for (final p in pageProducts) {
        current.add(p.id);
      }
    } else {
      for (final p in pageProducts) {
        current.remove(p.id);
      }
    }
    _selectedProductIdsNotifier.value = current;
  }

  void _clearSelection() {
    if (_selectedProductIdsNotifier.value.isNotEmpty) {
      _selectedProductIdsNotifier.value = {};
    }
  }

  Future<void> _toggleProductoActivo(
    ProductEntity product,
    AdminCatalogCubit cubit,
  ) async {
    await cubit.toggleProductActive(product);
  }

  Future<void> _confirmDeleteProduct(
    ProductEntity product,
    AdminCatalogCubit cubit,
  ) async {
    final variantCount = product.productVariants.length;
    final variantText =
        variantCount > 0 ? ' y sus $variantCount variantes vinculadas' : '';

    await AdaptiveDestructiveDialog.show(
      context: context,
      title: 'Eliminar Producto',
      itemName: product.name,
      matchText: product.name,
      description:
          'Esta acciÃ³n eliminarÃ¡ permanentemente "${product.name}"$variantText, sus cÃ³digos de barra, relaciones de inventario y configuraciÃ³n de precios.\n\nNota de Seguridad: La acciÃ³n serÃ¡ rechazada si el producto cuenta con existencias activas en almacÃ©n, Ã³rdenes de compra a proveedores, ventas o movimientos en Kardex.',
      confirmButtonText: 'Eliminar Producto',
      onConfirmAsync: () async {
        final success = await cubit.deleteProduct(product.id);
        if (success && mounted) {
          _toggleProductSelected(product.id, false);
          AppSnackbar.show(
            context,
            message: 'Producto eliminado correctamente',
            type: SnackbarType.success,
          );
        }
        return success;
      },
    );
  }

  Future<void> _handleExport(
    AdminCatalogCubit cubit,
    List<ProductEntity> products,
  ) async {
    final res = await CatalogDialogs.showExportOptionsDialog(
      context,
      products,
      products.length,
    );
    if (res != null && mounted) {
      String currencySymbol = 'S/';
      try {
        currencySymbol = context.read<AppConfigCubit>().state.currencySymbol;
      } catch (_) {}

      await cubit.exportCatalog(
        format: res.format,
        optionsMode: res.mode,
        selectedIds: res.selectedIds.toList(),
        currencySymbol: currencySymbol,
      );
    }
  }

  void _showProductQuickView(ProductEntity product, AdminCatalogCubit cubit) {
    ProductQuickViewSheet.show(
      context,
      product: product,
      cubit: cubit,
      onToggleActive: () => _toggleProductoActivo(product, cubit),
      onEdit: () {
        context.go(
          '/products/product-form/${product.id}',
          extra: {'productToEdit': product},
        );
      },
      onOpenFullDetail: () {
        context.go('/product/${product.id}', extra: product);
      },
    );
  }

  void _showProductQr(ProductEntity product) {
    final firstVariant =
        product.productVariants.isNotEmpty
            ? product.productVariants.first
            : null;
    InventoryQrSheet.show(
      context,
      productId: product.id,
      variantId: firstVariant?.id ?? '',
      productName: product.name,
      variantName: firstVariant?.label,
      sku: firstVariant?.sku,
      barcode: firstVariant?.barcode,
    );
  }

  // â”€â”€ PAGINACIÃ“N SLIVER (MÃ³vil / Tarjetas) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildPaginationSliver(
    AdminCatalogState state,
    AdminCatalogCubit cubit,
    BuildContext context,
  ) {
    if (state.products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 24));
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.03),
          ),
          child: AdminPageBlocks(
            currentPage: state.currentPage,
            totalPages: state.totalPages,
            onPageChanged: cubit.setPage,
            totalItems: state.totalCount,
            itemsPerPage: state.itemsPerPage,
            onItemsPerPageChanged: cubit.setItemsPerPage,
            itemName: 'productos',
          ),
        ),
      ),
    );
  }

  // â”€â”€ CONTENIDO PRINCIPAL SLIVER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSliverBody(
    AdminCatalogState state,
    AdminCatalogCubit cubit, {
    required bool isDesktop,
  }) {
    // Zero-Shimmer (SWR): Si ya hay datos en memoria/cachÃ©, mostrar de inmediato sin skeleton
    final hasCachedProducts = state.products.isNotEmpty;
    final isLoadingInitial =
        (state.catalogState == ViewState.loading ||
            state.catalogState == ViewState.initial) &&
        !hasCachedProducts;

    if (isLoadingInitial) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver:
            isDesktop
                ? SliverToBoxAdapter(
                  child: ProductsDesktopTable(
                    products: const [],
                    selectedProductIds: const {},
                    matchedIngredients: const {},
                    isLoading: true,
                    onProductSelected: (_, _) {},
                    onSelectAllPage: (_) {},
                    onRowTap: (_) {},
                    onToggleActive: (_) {},
                    onEdit: (_) {},
                    onDelete: (_) {},
                  ),
                )
                : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: AppShimmer(
                        width: double.infinity,
                        height: 104,
                        borderRadius: 16,
                      ),
                    ),
                    childCount: 6,
                  ),
                ),
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: CatalogErrorState(
                message: state.errorMessage!,
                onRetry: () => cubit.refreshProducts(),
              ),
            ),
          ),
        ),
      );
    }

    if (state.products.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 32,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se encontraron productos',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Prueba ajustando el tÃ©rmino de bÃºsqueda o cambiando los filtros seleccionados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      _searchCtrl.clear();
                      _clearSelection();
                      cubit.setSearchTerm('');
                      cubit.setCategory(null);
                      cubit.setStockFilter(CatalogStockFilter.all);
                      cubit.setFilterIsActive(null);
                      if (state.searchByIngredient) {
                        cubit.toggleSearchByIngredient(false);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Restablecer Filtros'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isDesktop) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: _selectedProductIdsNotifier,
            builder: (context, selectedIds, _) {
              return ProductsDesktopTable(
                products: state.products,
                selectedProductIds: selectedIds,
                matchedIngredients: state.matchedIngredients,
                onProductSelected: _toggleProductSelected,
                onSelectAllPage:
                    (selectAll) => _selectAllPage(state.products, selectAll),
                onRowTap: (p) => _showProductQuickView(p, cubit),
                onToggleActive: (p) => _toggleProductoActivo(p, cubit),
                onShowQr: _showProductQr,
                onEdit: (p) {
                  context.go(
                    '/products/product-form/${p.id}',
                    extra: {'productToEdit': p},
                  );
                },
                onDelete: (p) => _confirmDeleteProduct(p, cubit),
                paginationConfig: AdminTablePaginationConfig(
                  currentPage: state.currentPage + 1,
                  pageSize: state.itemsPerPage,
                  totalItems: state.totalCount,
                  totalPagesOverride: state.totalPages,
                  pageSizeOptions:
                      {15, 25, 50, 100, state.itemsPerPage}.toList()..sort(),
                  onPageChanged: (page) {
                    _clearSelection();
                    cubit.setPage(page - 1);
                  },
                  onPageSizeChanged: cubit.setItemsPerPage,
                ),
              );
            },
          ),
        ),
      );
    }

    // MÃ³vil / Tablet: VirtualizaciÃ³n estricta mediante SliverList (reciclaje de widgets y bajo consumo de RAM)
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      sliver: ProductsMobileSliverList(
        products: state.products,
        matchedIngredients: state.matchedIngredients,
        onTapProduct: (p) => _showProductQuickView(p, cubit),
        onToggleActive: (p) => _toggleProductoActivo(p, cubit),
        onEdit: (p) {
          context.go(
            '/products/product-form/${p.id}',
            extra: {'productToEdit': p},
          );
        },
        onDelete: (p) => _confirmDeleteProduct(p, cubit),
        onOpenFullDetail: (p) {
          context.go('/product/${p.id}', extra: p);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCatalogCubit>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 720;
        final isTablet = width >= 720 && width < 1100;

        return Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: BlocListener<AdminCatalogCubit, AdminCatalogState>(
            listenWhen:
                (previous, current) =>
                    previous.actionState != current.actionState ||
                    previous.currentPage != current.currentPage ||
                    previous.searchTerm != current.searchTerm ||
                    previous.selectedCategoryId != current.selectedCategoryId ||
                    previous.selectedBrandId != current.selectedBrandId ||
                    previous.stockFilter != current.stockFilter,
            listener: (context, state) {
              if (state.actionState == ViewState.error) {
                AppSnackbar.show(
                  context,
                  message: state.errorMessage ?? 'OcurriÃ³ un error',
                  type: SnackbarType.error,
                );
              }
              if (_selectedProductIdsNotifier.value.isNotEmpty) {
                _selectedProductIdsNotifier.value = {};
              }
            },
            child: AdminLayout(
              title: 'Inventario de Productos',
              actions:
                  isMobile
                      ? [
                        IconButton(
                          icon: const Icon(Icons.file_download_outlined),
                          tooltip: 'Exportar catÃ¡logo (Excel / PDF / CSV)',
                          onPressed:
                              () => _handleExport(cubit, cubit.state.products),
                        ),
                        if (context.hasAnyPermission(const [
                          AppPermissions.productsCreate,
                          AppPermissions.productsEdit,
                        ]))
                          IconButton(
                            icon: const Icon(Icons.upload_file_rounded),
                            tooltip: 'Importar Lote (Excel / CSV)',
                            onPressed:
                                () => context.go('/products/bulk-import'),
                          ),
                      ]
                      : null,
              floatingActionButton:
                  isMobile &&
                          context.hasPermission(AppPermissions.productsCreate)
                      ? ValueListenableBuilder<bool>(
                        valueListenable: _isFabExtended,
                        builder: (context, extended, child) {
                          return extended
                              ? FloatingActionButton.extended(
                                heroTag: 'products_add_fab',
                                onPressed:
                                    () => context.go('/products/product-form'),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text(
                                  'Nuevo Producto',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                              : FloatingActionButton(
                                heroTag: 'products_add_fab',
                                onPressed:
                                    () => context.go('/products/product-form'),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                tooltip: 'Nuevo Producto',
                                child: const Icon(Icons.add_rounded),
                              );
                        },
                      )
                      : null,
              body: Stack(
                children: [
                  Container(
                    color: AppColors.background,
                    child: RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh:
                          () async => cubit.refreshProducts(forceRefresh: true),
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // 0. Cabecera Ejecutiva Stripe / Linear
                          SliverToBoxAdapter(
                            child: AdminPageHeader(
                              title: 'CatÃ¡logo de Productos',
                              subtitle:
                                  'Administra precios, mÃ¡rgenes brutos, inventario en tiempo real y visibilidad multicanal.',
                              isDesktop: !isMobile,
                              actions: [
                                if (context.hasAnyPermission(const [
                                  AppPermissions.productsCreate,
                                  AppPermissions.productsEdit,
                                ]))
                                  AdminHeaderButton.outlined(
                                    label: 'Importar',
                                    icon: Icons.upload_file_rounded,
                                    tooltip: 'Importar lote de productos',
                                    onPressed:
                                        () =>
                                            context.go('/products/bulk-import'),
                                  ),
                                AdminHeaderButton.outlined(
                                  label: 'Exportar',
                                  icon: Icons.file_download_outlined,
                                  iconColor: const Color(0xFF10B981),
                                  tooltip:
                                      'Exportar catÃ¡logo en Excel, PDF o CSV',
                                  onPressed:
                                      () => _handleExport(
                                        cubit,
                                        cubit.state.products,
                                      ),
                                ),
                                if (context.hasPermission(
                                  AppPermissions.productsCreate,
                                ))
                                  AdminHeaderButton.primary(
                                    label: 'Nuevo Producto',
                                    icon: Icons.add_rounded,
                                    tooltip:
                                        'Registrar nuevo producto (Atajo: N)',
                                    onPressed:
                                        () => context.go(
                                          '/products/product-form',
                                        ),
                                  ),
                              ],
                            ),
                          ),

                          // 1. Bento Metric Strip (Pulso en Tiempo Real con BlocSelector)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: ProductsMetricsBar(
                                isMobile: isMobile,
                                isTablet: isTablet,
                              ),
                            ),
                          ),

                          // 2. Toolbar Pro Unificado (Desacoplado)
                          SliverToBoxAdapter(
                            child: ProductsToolbarWrapper(
                              isDesktop: !isMobile,
                              searchController: _searchCtrl,
                              searchFocusNode: _searchFocusNode,
                              isTableView: _isTableView,
                              onToggleTableView:
                                  (val) => setState(() => _isTableView = val),
                              onRefresh:
                                  () =>
                                      cubit.refreshProducts(forceRefresh: true),
                            ),
                          ),

                          // 3. Contenido Principal (Data-Grid vs Tarjetas Virtualizadas)
                          BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                            buildWhen:
                                (prev, current) =>
                                    prev.catalogState != current.catalogState ||
                                    prev.products != current.products ||
                                    prev.currentPage != current.currentPage ||
                                    prev.totalPages != current.totalPages ||
                                    prev.totalCount != current.totalCount ||
                                    prev.errorMessage != current.errorMessage ||
                                    prev.matchedIngredients !=
                                        current.matchedIngredients,
                            builder: (context, state) {
                              return _buildSliverBody(
                                state,
                                cubit,
                                isDesktop: !isMobile && _isTableView,
                              );
                            },
                          ),

                          // 4. PaginaciÃ³n MÃ³vil / Tarjetas
                          BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                            buildWhen:
                                (prev, current) =>
                                    prev.currentPage != current.currentPage ||
                                    prev.totalPages != current.totalPages ||
                                    prev.totalCount != current.totalCount ||
                                    prev.itemsPerPage != current.itemsPerPage ||
                                    prev.products.isEmpty !=
                                        current.products.isEmpty,
                            builder: (context, state) {
                              if (isMobile || !_isTableView) {
                                return _buildPaginationSliver(
                                  state,
                                  cubit,
                                  context,
                                );
                              }
                              return const SliverToBoxAdapter(
                                child: SizedBox(height: 28),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Overlay de carga de acciones
                  BlocSelector<AdminCatalogCubit, AdminCatalogState, ViewState>(
                    selector: (state) => state.actionState,
                    builder: (context, actionState) {
                      if (actionState == ViewState.loading) {
                        return Positioned.fill(
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.45),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
