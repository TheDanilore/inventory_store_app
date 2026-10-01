import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_fab_buttons.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_pro_table_view.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_product_skeleton.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_side_inspector.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';

/// Modos de visualización del catálogo de productos.
enum CatalogViewMode {
  grid,
  table,
}

class AdminCatalogScreen extends StatefulWidget {
  final Widget? floatingActionButton;
  final void Function(ProductEntity product)? onAddToCart;
  final void Function(ProductEntity product)? onProductTap;
  final VoidCallback? onProfileAvatarTap;

  const AdminCatalogScreen({
    super.key,
    this.floatingActionButton,
    this.onAddToCart,
    this.onProductTap,
    this.onProfileAvatarTap,
  });

  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Modo de visualización activo: Tarjetas visuales o Tabla Pro de alta densidad.
  CatalogViewMode _viewMode = CatalogViewMode.grid;

  /// Producto actualmente inspeccionado en el panel Master-Detail lateral.
  ProductEntity? _selectedProduct;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchCtrl.text = context.read<AdminCatalogCubit>().state.searchTerm;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Verifica si el foco activo actual reside dentro de un campo de texto editable.
  bool _isEditableFocused() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final context = primaryFocus.context;
    if (context == null) return false;
    return primaryFocus.context?.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<void> _navigateToProductForm({ProductEntity? product}) async {
    final cubit = context.read<AdminCatalogCubit>();
    final uri = product != null
        ? '/products/product-form/${product.id}'
        : '/products/product-form';

    final result = await context.push<bool>(
      uri,
      extra: product != null ? {'productToEdit': product} : null,
    );

    if (result == true && mounted) {
      await cubit.refreshProducts(forceRefresh: true);
      if (_selectedProduct != null &&
          product != null &&
          _selectedProduct!.id == product.id) {
        setState(() => _selectedProduct = null);
      }
    }
  }

  void _handleProductInteraction({
    required BuildContext context,
    required ProductEntity product,
    required bool isMobile,
    required bool isTablet,
    required AdminCatalogCubit cubit,
  }) {
    if (widget.onProductTap != null) {
      widget.onProductTap!(product);
      return;
    }

    if (isMobile) {
      CatalogSideInspector.showAsBottomSheet(
        context,
        product: product,
        onEdit: () => _navigateToProductForm(product: product),
        onAddToCart: () {
          if (widget.onAddToCart != null) {
            widget.onAddToCart!(product);
          } else {
            PosAddToCartSheet.show(context, product);
          }
        },
        onToggleActive: () => _toggleProductoActivo(product, cubit),
      );
    } else if (isTablet) {
      CatalogSideInspector.showAsDialog(
        context,
        product: product,
        onEdit: () => _navigateToProductForm(product: product),
        onAddToCart: () {
          if (widget.onAddToCart != null) {
            widget.onAddToCart!(product);
          } else {
            PosAddToCartSheet.show(context, product);
          }
        },
        onToggleActive: () => _toggleProductoActivo(product, cubit),
      );
    } else {
      setState(() {
        _selectedProduct =
            (_selectedProduct?.id == product.id) ? null : product;
      });
    }
  }

  Future<void> _toggleProductoActivo(
    ProductEntity product,
    AdminCatalogCubit cubit,
  ) async {
    final willActivate = !product.isActive;
    final success = await cubit.toggleProductActive(product);

    if (success && mounted) {
      // Actualizar producto seleccionado en el inspector si coincide
      if (_selectedProduct?.id == product.id) {
        setState(() {
          _selectedProduct = _selectedProduct!.copyWith(isActive: willActivate);
        });
      }

      AppSnackbar.show(
        context,
        message: willActivate
            ? '${product.name} ha sido activado'
            : '${product.name} ha sido pausado',
        type: willActivate ? SnackbarType.success : SnackbarType.info,
      );
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(AdminCatalogState state) {
    return [
      const PopupMenuItem(
        value: 'export',
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 18),
            SizedBox(width: 10),
            Text('Exportar a PDF'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'sync',
        child: Row(
          children: [
            Icon(Icons.sync_rounded, size: 18),
            SizedBox(width: 10),
            Text('Forzar Sincronización'),
          ],
        ),
      ),
    ];
  }

  Future<void> _handleMenuSelection(
    String value,
    AdminCatalogCubit cubit,
    AdminCatalogState state,
    BuildContext ctx,
  ) async {
    switch (value) {
      case 'export':
        await _exportCatalogPdf(ctx, cubit, state);
        break;
      case 'sync':
        await cubit.forceSync();
        if (ctx.mounted) {
          AppSnackbar.show(
            ctx,
            message: 'Sincronización completada exitosamente.',
            type: SnackbarType.success,
          );
        }
        break;
    }
  }

  Future<void> _exportCatalogPdf(
    BuildContext context,
    AdminCatalogCubit cubit,
    AdminCatalogState state,
  ) async {
    final allProducts = state.products;
    final max50Products = allProducts.take(50).toList();

    final options = await CatalogDialogs.showExportOptionsDialog(
      context,
      max50Products,
      state.products.length,
    );

    if (!context.mounted || options == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Generando Catálogo PDF...', textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    await cubit.exportCatalogPdf(
      optionsMode: options.mode,
      selectedIds: options.selectedIds.toList(),
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 650;
        final isTablet = screenWidth >= 650 && screenWidth < 1100;
        final isDesktop = screenWidth >= 1100;

        final cubit = context.read<AdminCatalogCubit>();

        final bodyContent = BlocListener<AdminCatalogCubit, AdminCatalogState>(
          listenWhen: (prev, current) =>
              prev.searchTerm != current.searchTerm ||
              (current.actionState == ViewState.error &&
                  prev.actionState != current.actionState) ||
              (current.errorMessage != null &&
                  prev.errorMessage != current.errorMessage &&
                  current.products.isNotEmpty),
          listener: (context, state) {
            if (_searchCtrl.text != state.searchTerm) {
              _searchCtrl.text = state.searchTerm;
            }
            if (state.errorMessage != null &&
                state.errorMessage!.isNotEmpty &&
                state.products.isNotEmpty) {
              AppSnackbar.show(
                context,
                message: state.errorMessage!,
                type: SnackbarType.error,
              );
            }
          },
          child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
            buildWhen: (prev, current) =>
                prev.catalogState != current.catalogState ||
                prev.products != current.products ||
                prev.categories != current.categories ||
                prev.selectedCategoryId != current.selectedCategoryId ||
                prev.brands != current.brands ||
                prev.selectedBrandId != current.selectedBrandId ||
                prev.searchTerm != current.searchTerm ||
                prev.searchByIngredient != current.searchByIngredient ||
                prev.filterIsActive != current.filterIsActive ||
                prev.sortOption != current.sortOption ||
                prev.stockFilter != current.stockFilter ||
                prev.currentPage != current.currentPage ||
                prev.totalPages != current.totalPages ||
                prev.totalCount != current.totalCount ||
                prev.actionState != current.actionState ||
                prev.errorMessage != current.errorMessage,
            builder: (context, state) {
              final double fabsBottomPadding = isMobile ? 128.0 : 16.0;

              Widget mainContent = Builder(
                builder: (context) {
                  final headerSliver = SliverPersistentHeader(
                    pinned: true,
                    delegate: _CatalogHeaderDelegate(
                      minHeight: 70.0,
                      maxHeight: state.searchByIngredient ? 122.0 : 70.0,
                      isExporting: state.actionState == ViewState.loading,
                      searchByIngredient: state.searchByIngredient,
                      child: Container(
                        color: AppColors.background,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CatalogHeader(
                              searchController: _searchCtrl,
                              searchFocusNode: _searchFocusNode,
                              isExporting: state.actionState == ViewState.loading,
                              isTableView: _viewMode == CatalogViewMode.table,
                              onToggleTableView: (isTable) {
                                setState(() {
                                  _viewMode = isTable
                                      ? CatalogViewMode.table
                                      : CatalogViewMode.grid;
                                });
                              },
                              onExport: () => _exportCatalogPdf(
                                context,
                                cubit,
                                state,
                              ),
                              onSearchSubmitted: cubit.submitSearch,
                              searchByIngredient: state.searchByIngredient,
                              onToggleIngredientSearch:
                                  cubit.toggleSearchByIngredient,
                              onAddProduct: () => _navigateToProductForm(),
                            ),
                            if (state.actionState == ViewState.loading)
                              const LinearProgressIndicator(
                                color: AppColors.teal,
                                minHeight: 2,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final chipsSliver = !state.searchByIngredient
                      ? SliverToBoxAdapter(
                          child: CategoryChips(
                            categories: state.categories,
                            selectedCategoryId: state.selectedCategoryId,
                            onSelected: cubit.setCategory,
                            brands: state.brands,
                            selectedBrandId: state.selectedBrandId,
                            onBrandSelected: cubit.setBrand,
                            filterIsActive: state.filterIsActive,
                            onStatusSelected: cubit.setFilterIsActive,
                            sortOption: state.sortOption,
                            onSortSelected: cubit.setSortOption,
                            stockFilter: state.stockFilter,
                            onStockFilterSelected: cubit.setStockFilter,
                            onClearAllFilters: cubit.resetAllFilters,
                          ),
                        )
                      : null;

                  // ── Estado de Carga (Skeletons Shimmer) ───────────────────
                  if (state.catalogState == ViewState.loading ||
                      state.catalogState == ViewState.initial) {
                    return RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: () async => cubit.refreshProducts(),
                      child: CustomScrollView(
                        slivers: [
                          headerSliver,
                          if (chipsSliver != null) chipsSliver,
                          if (_viewMode == CatalogViewMode.table && !isMobile)
                            const SliverPadding(
                              padding: EdgeInsets.all(16),
                              sliver: SliverToBoxAdapter(
                                child: CatalogTableSkeleton(),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 260,
                                  mainAxisExtent: 280,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                      const AdminProductSkeleton(),
                                  childCount: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  // ── Estado de Error ───────────────────────────────────────
                  if (state.errorMessage != null && state.products.isEmpty) {
                    return RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: () async => cubit.refreshProducts(),
                      child: CustomScrollView(
                        slivers: [
                          headerSliver,
                          if (chipsSliver != null) chipsSliver,
                          SliverFillRemaining(
                            child: CatalogErrorState(
                              message: (state.errorMessage ?? ''),
                              onRetry: () => cubit.refreshProducts(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ── Estado Vacío ──────────────────────────────────────────
                  if (state.products.isEmpty &&
                      (state.catalogState == ViewState.success ||
                          state.catalogState == ViewState.empty)) {
                    return RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: () async => cubit.refreshProducts(),
                      child: CustomScrollView(
                        slivers: [
                          headerSliver,
                          if (chipsSliver != null) chipsSliver,
                          SliverFillRemaining(
                            child: CatalogEmptyState(
                              searchByIngredient: state.searchByIngredient,
                              searchTerm: state.searchTerm,
                              onRetry: () {
                                if (state.searchTerm.isNotEmpty) {
                                  _searchCtrl.clear();
                                  cubit.clearSearch();
                                } else {
                                  cubit.refreshProducts(forceRefresh: true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ── Vista Tabla Pro (Desktop & Tablet) ────────────────────
                  if (_viewMode == CatalogViewMode.table && !isMobile) {
                    return RefreshIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      onRefresh: () async => cubit.refreshProducts(),
                      child: CatalogProTableView(
                        products: state.products,
                        pageSize: AdminCatalogState.pageSize,
                        currentPage: state.currentPage,
                        totalCount: state.totalCount,
                        onPageChanged: cubit.setPage,
                        headerSliver: headerSliver,
                        chipsSliver: chipsSliver,
                        bottomPadding: fabsBottomPadding,
                        selectedProduct: _selectedProduct,
                        onProductSelected: (product) =>
                            _handleProductInteraction(
                          context: context,
                          product: product,
                          isMobile: isMobile,
                          isTablet: isTablet,
                          cubit: cubit,
                        ),
                        onSale: widget.onAddToCart ??
                            (product) =>
                                PosAddToCartSheet.show(context, product),
                        onToggleActive: (p) => _toggleProductoActivo(p, cubit),
                        onEdit: (product) => _navigateToProductForm(product: product),
                      ),
                    );
                  }

                  // ── Vista Cuadrícula Fluid (Móvil / Tablet / Desktop) ──────
                  return RefreshIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    onRefresh: () async => cubit.refreshProducts(),
                    child: CatalogGridScrollView(
                      products: state.products,
                      pageSize: AdminCatalogState.pageSize,
                      currentPage: state.currentPage,
                      totalCount: state.totalCount,
                      onPageChanged: cubit.setPage,
                      onSale: widget.onAddToCart ??
                          (product) =>
                              PosAddToCartSheet.show(context, product),
                      onToggleActive: (p) => _toggleProductoActivo(p, cubit),
                      onProductTap: (product) => _handleProductInteraction(
                        context: context,
                        product: product,
                        isMobile: isMobile,
                        isTablet: isTablet,
                        cubit: cubit,
                      ),
                      selectedProductId: _selectedProduct?.id,
                      searchByIngredient: state.searchByIngredient,
                      matchedIngredients: state.matchedIngredients,
                      bottomPadding: fabsBottomPadding,
                      headerSliver: headerSliver,
                      chipsSliver: chipsSliver,
                      onEdit: (product) => _navigateToProductForm(product: product),
                      isPosMode: false,
                    ),
                  );
                },
              );

              Widget catalogBody = Column(
                children: [
                  Expanded(child: mainContent),
                ],
              );

              // ── Master-Detail Layout ÚNICAMENTE en Desktop (>= 1100dp) ──
              // En Móvil y Tablet se abre como BottomSheet o Diálogo modal centrado
              if (isDesktop && _selectedProduct != null) {
                catalogBody = Row(
                  children: [
                    Expanded(child: catalogBody),
                    CatalogSideInspector(
                      product: _selectedProduct!,
                      onClose: () => setState(() => _selectedProduct = null),
                      onEdit: () => _navigateToProductForm(product: _selectedProduct),
                      onAddToCart: () {
                        if (widget.onAddToCart != null) {
                          widget.onAddToCart!(_selectedProduct!);
                        } else {
                          PosAddToCartSheet.show(context, _selectedProduct!);
                        }
                      },
                      onToggleActive: () =>
                          _toggleProductoActivo(_selectedProduct!, cubit),
                    ),
                  ],
                );
              }

              if (isDesktop || isTablet) {
                return Container(
                  color: AppColors.background,
                  child: catalogBody,
                );
              }

              return catalogBody;
            },
          ),
        );

        // ── Botones Flotantes (ESTRICTAMENTE solo en Móvil, NUNCA en Desktop/Tablet) ──
        final Widget? effectiveFab;
        if (isMobile) {
          effectiveFab = CatalogMobileActionDock(
            onAddProduct: () => _navigateToProductForm(),
            customCartFab: widget.floatingActionButton,
          );
        } else {
          // En Desktop y Tablet la acción de POS ya está en la barra superior y sidebar
          effectiveFab = null;
        }

        return AdminLayout(
          title: 'Catálogo',
          showSettingsButton: true,
          settingsActions: _buildMenuItems(cubit.state),
          onSettingsSelected: (value) =>
              _handleMenuSelection(value, cubit, cubit.state, context),
          showAppBar: true,
          actions: [
            if (!isMobile)
              ElevatedButton.icon(
                onPressed: () => context.go('/pos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                label: const Text(
                  'Punto de Venta (POS) [P]',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
          body: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final isAlt = HardwareKeyboard.instance.isAltPressed;
                final isControl = HardwareKeyboard.instance.isControlPressed;
                final isMeta = HardwareKeyboard.instance.isMetaPressed;
                final isModifier = isAlt || isControl || isMeta;
                final isTyping = _isEditableFocused();

                // Escape: Descartar inspector lateral o desenfocar buscador (siempre activo)
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  if (_selectedProduct != null) {
                    setState(() => _selectedProduct = null);
                    return KeyEventResult.handled;
                  }
                  if (_searchFocusNode.hasFocus) {
                    _searchFocusNode.unfocus();
                    return KeyEventResult.handled;
                  }
                }

                // Si el usuario está escribiendo dentro de un TextField, no disparamos atajos de tecla única
                if (isTyping && !isModifier) {
                  return KeyEventResult.ignored;
                }

                // ── Atajos Globales y de Tecla Única (Estilo Pro Tools / Linear) ──

                // '/' o ⌘K / Ctrl+K / Alt+K: Enfocar buscador y seleccionar texto
                if ((event.logicalKey == LogicalKeyboardKey.slash && !isModifier) ||
                    (isModifier && event.logicalKey == LogicalKeyboardKey.keyK)) {
                  _searchFocusNode.requestFocus();
                  _searchCtrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _searchCtrl.text.length,
                  );
                  return KeyEventResult.handled;
                }

                // 'P' o Alt+P: Ir a Punto de Venta (POS)
                if ((event.logicalKey == LogicalKeyboardKey.keyP && !isModifier) ||
                    (isAlt && event.logicalKey == LogicalKeyboardKey.keyP)) {
                  context.go('/pos');
                  return KeyEventResult.handled;
                }

                // 'N' o Alt+N / Ctrl+N: Crear nuevo producto
                if ((event.logicalKey == LogicalKeyboardKey.keyN && !isModifier) ||
                    (isModifier && event.logicalKey == LogicalKeyboardKey.keyN)) {
                  _navigateToProductForm();
                  return KeyEventResult.handled;
                }

                // 'R' o Alt+R: Forzar recarga del catálogo
                if ((event.logicalKey == LogicalKeyboardKey.keyR && !isModifier) ||
                    (isAlt && event.logicalKey == LogicalKeyboardKey.keyR)) {
                  cubit.refreshProducts(forceRefresh: true);
                  AppSnackbar.show(
                    context,
                    message: 'Sincronizando catálogo...',
                    type: SnackbarType.info,
                  );
                  return KeyEventResult.handled;
                }

                // 'V' o ⌘V / Ctrl+V / Alt+V: Alternar vista Cuadrícula / Tabla Pro
                if ((event.logicalKey == LogicalKeyboardKey.keyV && !isModifier) ||
                    (isModifier && event.logicalKey == LogicalKeyboardKey.keyV)) {
                  setState(() {
                    _viewMode = _viewMode == CatalogViewMode.grid
                        ? CatalogViewMode.table
                        : CatalogViewMode.grid;
                  });
                  return KeyEventResult.handled;
                }

                // 'T' o ⌘T / Ctrl+T / Alt+T: Alternar modo Producto / Ingrediente
                if ((event.logicalKey == LogicalKeyboardKey.keyT && !isModifier) ||
                    (isModifier && event.logicalKey == LogicalKeyboardKey.keyT)) {
                  cubit.toggleSearchByIngredient(
                    !cubit.state.searchByIngredient,
                  );
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: bodyContent,
          ),
          floatingActionButton: effectiveFab,
          bottomNavigationBar: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
            buildWhen: (prev, curr) =>
                prev.products != curr.products ||
                prev.currentPage != curr.currentPage ||
                prev.totalPages != curr.totalPages,
            builder: (context, state) {
              if (state.products.isEmpty || state.totalPages < 1) {
                return const SizedBox.shrink();
              }
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: const Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: AdminPageBlocks(
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  onPageChanged: cubit.setPage,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CatalogHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;
  final bool isExporting;
  final bool searchByIngredient;

  _CatalogHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
    required this.isExporting,
    required this.searchByIngredient,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _CatalogHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        isExporting != oldDelegate.isExporting ||
        searchByIngredient != oldDelegate.searchByIngredient;
  }
}
