import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/pos_provider.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';

import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/desktop_pos_panel.dart';

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final repo = sl<ProductsRepository>();
      final variantsMapRes = await repo.fetchVariantsByProductIds([product.id]);
        final variantsMap = variantsMapRes.fold((l) => <String, List<ProductVariantEntity>>{}, (r) => r);
      final variants = variantsMap[product.id] ?? [];

      if (!mounted) return;
      Navigator.pop(context); // cerrar loader

      if (variants.isEmpty || variants.length == 1) {
        final variant = variants.isNotEmpty ? variants.first : null;
        int stock = 0;

        if (product.stockControl) {
          if (variant != null) {
            final stockMapRes = await repo.fetchVariantStockByVariantIds([
              variant.id,
            ]);
            final stockMap = stockMapRes.fold((l) => <String, int>{}, (r) => r);
            stock = stockMap[variant.id] ?? 0;
          } else {
            stock = product.totalStock; // stock total si no hay variante
          }
        } else {
          stock = 999999;
        }

        if (stock > 0 || !product.stockControl) {
          if (!mounted) return;
          final pos = context.read<PosProvider>();
          pos.addProductToPos(
            product: product,
            quantity: 1,
            variantId: variant?.id,
            variantLabel: variant?.label,
            unitPrice: variant?.salePrice ?? product.salePrice,
            unitCost: variant?.unitCost ?? product.unitCost,
            imageUrl:
                (variant != null && variant.images.isNotEmpty)
                    ? variant.images.first.imageUrl
                    : product.primaryImageUrl,
            sku: variant?.sku,
            availableStock: product.stockControl ? stock : 999999,
          );
          if (mounted) {
            AppSnackbar.show(
              context,
              message: '${product.name} agregado a la caja.',
              type: SnackbarType.success,
            );
          }
          return;
        } else {
          if (!mounted) return;
          AppSnackbar.show(
            context,
            message: 'Producto agotado.',
            type: SnackbarType.warning,
          );
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cerrar loader si falla
        AppSnackbar.show(
          context,
          message: 'Error al verificar variantes: $e',
          type: SnackbarType.error,
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: PosAddToCartSheet(productEntity: product),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      floatingActionButton: MediaQuery.of(context).size.width >= 800 
          ? null 
          : FloatingActionButton.extended(
              onPressed: () => context.push('/admin/pos-checkout'),
              label: const Text('Ir a Caja'),
              icon: const Icon(Icons.shopping_cart_checkout),
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
