import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/desktop_pos_panel.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/pos_processing_overlay.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_sidebar_rail.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_sales_view.dart';

extension ProductToCartExtension on ProductEntity {
  CartItemEntity toCartItem() {
    return CartItemEntity(
      productId: id,
      productName: name,
      cartKey: id,
      quantity: 1,
      unitPrice: displaySalePrice ?? 0.0,
      unitCost: defaultVariant?.unitCost ?? 0.0,
      availableStock: stockControl ? totalStock : 999999,
      usesBatches: false,
      wholesalePrice: defaultVariant?.wholesalePrice,
      imageUrl: primaryImageUrl,
      isSelected: true,
    );
  }
}

class AdminPosScreen extends StatefulWidget {
  const AdminPosScreen({super.key});

  @override
  State<AdminPosScreen> createState() => _AdminPosScreenState();
}

class _AdminPosScreenState extends State<AdminPosScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _desktopPanelKey = GlobalKey<DesktopPosPanelState>();
  late final AdminCatalogCubit _catalogCubit;
  int _selectedSidebarIndex = 0;
  InventoryCubit? _inventoryCubit;

  @override
  void initState() {
    super.initState();
    _catalogCubit = context.read<AdminCatalogCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _catalogCubit.setFilterIsActive(true); // Asegurar que no se vendan productos inactivos
      if (_searchCtrl.text != _catalogCubit.state.searchTerm) {
        _searchCtrl.text = _catalogCubit.state.searchTerm;
      }

      // [QA CRITICAL FIX] Inicializar POS (almacenes, cuentas y turno activo) en el ciclo de vida raíz.
      // Previene que en mobile la cabecera quede sin almacenes ni turno al no montarse DesktopPosPanel.
      final posCubit = context.read<PosCubit>();
      if (posCubit.state.warehouses.isEmpty || posCubit.state.accounts.isEmpty) {
        posCubit.initPosData();
      }
    });
  }

  void _onSearchChanged(String val) {
    _catalogCubit.submitSearch(val, force: true);
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchCtrl.text.length,
    );
  }

  void _onSidebarTabSelected(int index) {
    if (index == 1 && _inventoryCubit == null) {
      _inventoryCubit = sl<InventoryCubit>()..initStockTab();
    }
    setState(() => _selectedSidebarIndex = index);
  }

  Future<void> _onExitPos() async {
    final cart = context.read<CartCubit>();
    if (cart.state.items.isNotEmpty) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('¿Salir de Caja POS?'),
            ],
          ),
          content: const Text(
            'Tienes productos agregados en la caja. Si sales al panel administrativo, la venta actual continuará en tu carrito para cuando regreses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Quedarme en Caja'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF142B1A),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Salir al ERP'),
            ),
          ],
        ),
      );
      if (shouldExit == true && mounted) {
        context.go('/');
      }
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _catalogCubit.setFilterIsActive(null); // Restaurar catálogo para mostrar todos los estados
    _inventoryCubit?.close();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _irAVenta(ProductEntity product) async {
    if (product.productVariants.isEmpty && !product.usesBatches) {
      final cart = context.read<CartCubit>();
      cart.addItem(product.toCartItem());
      return;
    }

    PosAddToCartSheet.show(context, product);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Foco de Búsqueda (Ctrl+K, Meta+K, Alt+B)
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyB, alt: true): _focusSearch,

        // Navegación Sidebar: Venta (Alt+1 / Alt+V)
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => _onSidebarTabSelected(0),
        const SingleActivator(LogicalKeyboardKey.keyV, alt: true): () => _onSidebarTabSelected(0),

        // Navegación Sidebar: Lotes / Stock (Alt+2 / Alt+S)
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => _onSidebarTabSelected(1),
        const SingleActivator(LogicalKeyboardKey.keyS, alt: true): () => _onSidebarTabSelected(1),

        // Navegación Sidebar: Ventas / Historial (Alt+3 / Alt+H)
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => _onSidebarTabSelected(2),
        const SingleActivator(LogicalKeyboardKey.keyH, alt: true): () => _onSidebarTabSelected(2),

        // Alternar modo de búsqueda Producto vs Ingrediente Activo (Alt+T)
        const SingleActivator(LogicalKeyboardKey.keyT, alt: true): () {
          _catalogCubit.toggleSearchByIngredient(!_catalogCubit.state.searchByIngredient);
        },

        // Cobrar Inmediato en Desktop (F2 o Alt+C)
        const SingleActivator(LogicalKeyboardKey.f2): () {
          _desktopPanelKey.currentState?.triggerCheckout();
        },
        const SingleActivator(LogicalKeyboardKey.keyC, alt: true): () {
          _desktopPanelKey.currentState?.triggerCheckout();
        },

        // Salir al ERP (Escape con confirmación si no hay focus en búsqueda)
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          } else {
            _onExitPos();
          }
        },
      },
      child: BlocListener<CartCubit, CartState>(
        listenWhen:
            (previous, current) =>
                (current.errorMessage != null &&
                    current.errorMessage != previous.errorMessage) ||
                (current.items.length > previous.items.length),
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackbar.show(
              context,
              message: state.errorMessage!,
              type: SnackbarType.warning,
            );
          } else if (state.items.isNotEmpty) {
            // Un item ha sido agregado exitosamente: feedback táctil sin saturar con SnackBars
            HapticFeedback.lightImpact();
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedSidebarIndex,
                  onDestinationSelected: _onSidebarTabSelected,
                  backgroundColor: Colors.white,
                  elevation: 8,
                  indicatorColor: const Color(0xFFD4E157).withValues(alpha: 0.25),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF1B4D3E)),
                      label: 'Venta',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2, color: Color(0xFF1B4D3E)),
                      label: 'Lotes/Stock',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF1B4D3E)),
                      label: 'Ventas',
                    ),
                  ],
                ),
          body: Builder(
            builder: (context) {
              Widget catalogContent = Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        BlocSelector<AdminCatalogCubit, AdminCatalogState, bool>(
                          selector: (state) => state.searchByIngredient,
                          builder: (context, searchByIngredient) {
                            return PosHeader(
                              searchController: _searchCtrl,
                              searchFocusNode: _searchFocusNode,
                              onSearchChanged: _onSearchChanged,
                              searchByIngredient: searchByIngredient,
                              onToggleIngredientSearch:
                                  context.read<AdminCatalogCubit>().toggleSearchByIngredient,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                          buildWhen: (prev, current) =>
                              prev.categories != current.categories ||
                              prev.selectedCategoryId != current.selectedCategoryId ||
                              prev.brands != current.brands ||
                              prev.selectedBrandId != current.selectedBrandId ||
                              prev.filterIsActive != current.filterIsActive ||
                              prev.sortOption != current.sortOption ||
                              prev.stockFilter != current.stockFilter,
                          builder: (context, state) {
                            if (state.categories.isEmpty && state.brands.isEmpty) return const SizedBox.shrink();
                            return CategoryChips(
                              categories: state.categories,
                              selectedCategoryId: state.selectedCategoryId,
                              onSelected: context.read<AdminCatalogCubit>().setCategory,
                              brands: state.brands,
                              selectedBrandId: state.selectedBrandId,
                              onBrandSelected: context.read<AdminCatalogCubit>().setBrand,
                              filterIsActive: state.filterIsActive,
                              onStatusSelected: context.read<AdminCatalogCubit>().setFilterIsActive,
                              sortOption: state.sortOption,
                              onSortSelected: context.read<AdminCatalogCubit>().setSortOption,
                              stockFilter: state.stockFilter,
                              onStockFilterSelected: context.read<AdminCatalogCubit>().setStockFilter,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                      buildWhen: (prev, current) =>
                          prev.products != current.products ||
                          prev.catalogState != current.catalogState ||
                          prev.errorMessage != current.errorMessage,
                      builder: (context, state) =>
                          _buildMainContent(context, context.read<AdminCatalogCubit>(), state),
                    ),
                  ),
                  BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                    buildWhen: (prev, current) =>
                        prev.currentPage != current.currentPage ||
                        prev.totalPages != current.totalPages ||
                        prev.products != current.products,
                    builder: (context, state) {
                      if (state.products.isNotEmpty && state.totalPages > 1) {
                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: AdminPageBlocks(
                              currentPage: state.currentPage,
                              totalPages: state.totalPages,
                              onPageChanged: context.read<AdminCatalogCubit>().setPage,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );

              Widget activeView;
              if (_selectedSidebarIndex == 1) {
                _inventoryCubit ??= sl<InventoryCubit>()..initStockTab();
                activeView = Expanded(
                  child: BlocProvider.value(
                    value: _inventoryCubit!,
                    child: const InventoryScreen(isEmbedded: true),
                  ),
                );
              } else if (_selectedSidebarIndex == 2) {
                activeView = const Expanded(child: PosSalesView());
              } else {
                activeView = Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 6, child: catalogContent),
                      if (isDesktop)
                        Container(
                          width:
                              MediaQuery.of(context).size.width >= 1300
                                  ? 440
                                  : MediaQuery.of(context).size.width >= 1000
                                  ? 400
                                  : 360,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              left: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 24,
                                spreadRadius: -4,
                                offset: const Offset(-8, 0),
                              ),
                            ],
                          ),
                          child: DesktopPosPanel(
                            key: _desktopPanelKey,
                            onSaleCompleted: (soldQuantities) {
                              context
                                  .read<AdminCatalogCubit>()
                                  .decrementStockLocal(soldQuantities);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isDesktop)
                        PosSidebarRail(
                          selectedIndex: _selectedSidebarIndex,
                          onDestinationSelected: _onSidebarTabSelected,
                          onExitPos: _onExitPos,
                        ),
                      activeView,
                    ],
                  ),
                  // Overlay global de procesamiento: cubre toda la pantalla
                  BlocSelector<PosCubit, PosState, bool>(
                    selector: (s) => s.status == PosStatus.loading,
                    builder:
                        (ctx, isLoading) =>
                            isLoading
                                ? const PosProcessingOverlay(isVisible: true)
                                : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
          floatingActionButton:
              isDesktop || _selectedSidebarIndex != 0
                  ? null
                  : BlocBuilder<CartCubit, CartState>(
                      builder: (context, cartState) {
                        final hasItems = cartState.items.isNotEmpty;
                        final itemCount = cartState.items.values.fold<int>(
                          0,
                          (sum, item) => sum + item.quantity,
                        );
                        final totalAmount = cartState.totalAmount;

                        return FloatingActionButton.extended(
                          onPressed: () async {
                            final sold = await context.push<Map<String, int>>('/pos-checkout');
                            if (sold != null && context.mounted) {
                              context.read<AdminCatalogCubit>().decrementStockLocal(sold);
                            }
                          },
                          backgroundColor:
                              hasItems
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                          foregroundColor: Colors.white,
                          icon: Icon(
                            hasItems
                                ? Icons.shopping_bag_rounded
                                : Icons.shopping_cart_checkout_rounded,
                            size: 20,
                          ),
                          label: Text(
                            hasItems
                                ? 'Ir a Caja ($itemCount) • S/ ${totalAmount.toStringAsFixed(2)}'
                                : 'Ir a Caja',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AdminCatalogCubit cubit,
    AdminCatalogState state,
  ) {
    if ((state.catalogState == ViewState.loading) && state.products.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:
              MediaQuery.of(context).size.width >= 1200
                  ? 6
                  : MediaQuery.of(context).size.width >= 800
                      ? 4
                      : MediaQuery.of(context).size.width >= 600
                          ? 3
                          : 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return const AppShimmer(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 16,
          );
        },
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return Center(child: CatalogErrorState(message: state.errorMessage!));
    }

    if (state.products.isEmpty && !(state.catalogState == ViewState.loading)) {
      return Center(
        child: CatalogEmptyState(
          searchByIngredient: state.searchByIngredient,
          searchTerm: state.searchTerm,
        ),
      );
    }

    return CatalogGridScrollView(
      products: state.products,
      pageSize: AdminCatalogState.pageSize,
      currentPage: state.currentPage,
      totalCount: state.totalCount,
      onPageChanged: cubit.setPage,
      onSale: _irAVenta,
      onToggleActive:
          (p) => Future.value(), // No permitimos editar en modo caja
      searchByIngredient: state.searchByIngredient,
      matchedIngredients: state.matchedIngredients,
      bottomPadding: MediaQuery.of(context).size.width >= 800 ? 24 : 100,
      isPosMode: true,
      onEdit: (product) {}, // No permitimos editar en modo caja
    );
  }
}
