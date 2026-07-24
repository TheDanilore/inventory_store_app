import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';

import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/desktop_pos_panel.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_operations_drawer.dart';

class AdminPosScreen extends StatefulWidget {
  const AdminPosScreen({super.key});

  @override
  State<AdminPosScreen> createState() => _AdminPosScreenState();
}

class _AdminPosScreenState extends State<AdminPosScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<AdminCatalogCubit>();
      _searchCtrl.text = cubit.state.searchTerm;
      // Removido cubit.refreshProducts() para evitar lag.
      // El POS usa la data ya cacheada por AdminCatalogScreen.
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _irAVenta(ProductEntity product) async {
    if (product.productVariants.isEmpty && !product.usesBatches) {
      if (product.stockControl && product.totalStock <= 0) {
        AppSnackbar.show(
          context,
          message: 'Producto agotado.',
          type: SnackbarType.warning,
        );
        return;
      }

      final cart = context.read<CartCubit>();
      cart.addItem(
        CartItemEntity(
          productId: product.id,
          productName: product.name,
          cartKey: product.id,
          quantity: 1,
          unitPrice: product.salePrice,
          unitCost: product.unitCost,
          availableStock: product.stockControl ? product.totalStock : 999999,
          usesBatches: false,
          wholesalePrice: product.wholesalePrice,
          imageUrl: product.primaryImageUrl,
          isSelected: true,
        ),
      );

      AppSnackbar.show(
        context,
        message: '${product.name} agregado al carrito',
        type: SnackbarType.success,
      );
      return;
    }

    PosAddToCartSheet.show(context, product);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f1): () {
          // F1: Enfocar campo de búsqueda
        },
        const SingleActivator(LogicalKeyboardKey.f2): () {
          // F2: Ir a Cobro / Checkout
          context.push('/admin/pos-checkout');
        },
        const SingleActivator(LogicalKeyboardKey.f4): () {
          // F4: Limpiar Carrito
          context.read<CartCubit>().clearCart();
          AppSnackbar.show(
            context,
            message: 'Carrito vaciado mediante atajo F4',
            type: SnackbarType.info,
          );
        },
        const SingleActivator(LogicalKeyboardKey.f5): () {
          // F5: Refrescar catálogo
          context.read<AdminCatalogCubit>().refreshProducts();
          AppSnackbar.show(
            context,
            message: 'Refrescando catálogo...',
            type: SnackbarType.info,
          );
        },
      },
      child: Scaffold(
        drawer: const PosOperationsDrawer(),
        backgroundColor: const Color(0xFFF7F8FC),
        body: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
          builder: (context, state) {
            final cubit = context.read<AdminCatalogCubit>();

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
                      CatalogHeader(
                        searchController: _searchCtrl,
                        isExporting: state.actionState == ViewState.loading,
                        onExport: () {},
                        onSearchChanged: cubit.setSearchTerm,
                        searchByIngredient: state.searchByIngredient,
                        onToggleIngredientSearch:
                            cubit.toggleSearchByIngredient,
                        isPosMode: true,
                        onBack: () => context.go('/admin'),
                        onAddProduct: () async {
                          final result = await context.push(
                            '/admin/product-form',
                          );
                          if (result == true) {
                            cubit.refreshProducts();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (state.categories.isNotEmpty)
                        CategoryChips(
                          categories: state.categories,
                          selectedCategoryId: state.selectedCategoryId,
                          onSelected: cubit.setCategory,
                          filterIsActive: state.filterIsActive,
                          onStatusSelected: cubit.setFilterIsActive,
                          sortOption: state.sortOption,
                          onSortSelected: cubit.setSortOption,
                          stockFilter: state.stockFilter,
                          onStockFilterSelected: cubit.setStockFilter,
                        ),
                    ],
                  ),
                ),
                Expanded(child: _buildMainContent(cubit, state)),
                if (state.products.isNotEmpty && state.totalPages > 1)
                  Container(
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
                        onPageChanged: cubit.setPage,
                      ),
                    ),
                  ),
              ],
            );

            final isDesktop = MediaQuery.of(context).size.width >= 800;

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: catalogContent),
                  Container(
                    width: 440,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(-3, 0),
                        ),
                      ],
                    ),
                    child: DesktopPosPanel(
                      onSaleCompleted: () {
                        cubit.refreshProducts();
                      },
                    ),
                  ),
                ],
              );
            } else {
              return catalogContent;
            }
          },
        ),
        floatingActionButton:
            MediaQuery.of(context).size.width >= 800
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
                      onPressed: () => context.push('/admin/pos-checkout'),
                      backgroundColor:
                          hasItems ? AppColors.primary : AppColors.textPrimary,
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
    );
  }

  Widget _buildMainContent(AdminCatalogCubit cubit, AdminCatalogState state) {
    if ((state.catalogState == ViewState.loading) && state.products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
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
      pageSize: 20,
      currentPage: state.currentPage,
      onPageChanged: cubit.setPage,
      onSale: _irAVenta,
      onToggleActive:
          (p) => Future.value(), // No permitimos editar en modo caja
      searchByIngredient: state.searchByIngredient,
      matchedIngredients: state.matchedIngredients,
      bottomPadding: 24,
      isPosMode: true,
      onEdit: (product) {}, // No permitimos editar en modo caja
    );
  }
}
