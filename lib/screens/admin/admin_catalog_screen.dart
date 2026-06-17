import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:inventory_store_app/providers/admin/admin_catalog_provider.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/services/admin/catalog_pdf_generator.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_header.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/admin_add_to_cart_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_fab_buttons.dart';

class AdminCatalogScreen extends StatefulWidget {
  const AdminCatalogScreen({super.key});

  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminCatalogProvider>();
      _searchCtrl.text = provider.searchTerm;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCatalogPdf(AdminCatalogProvider provider) async {
    if (provider.isLoadingAction) return;
    try {
      provider.setLoadingAction(true);

      // Usar _service directamente para traer un bloque crudo sin afectar la paginación de la pantalla
      final service = CatalogService();
      final allProductsResult = await service.loadProducts(
        categoryId: provider.selectedCategoryId,
        searchTerm: provider.searchTerm,
        isAdmin: true,
        filterIsActive: provider.filterIsActive,
      );
      final allProducts = allProductsResult.products;

      if (!mounted) return;

      if (allProducts.isEmpty) {
        AppSnackbar.show(
          context,
          message: 'No hay productos para exportar.',
          type: SnackbarType.error,
        );
        return;
      }

      final visibleProducts = provider.products;
      final max50Products = allProducts.take(50).toList();

      final options = await CatalogDialogs.showExportOptionsDialog(
        context,
        max50Products,
        visibleProducts.length,
      );

      if (!mounted || options == null) return;

      List<ProductModel> filteredProducts = [];
      if (options.mode == 0) {
        filteredProducts = visibleProducts;
      } else if (options.mode == 1) {
        filteredProducts = max50Products;
      } else if (options.mode == 2) {
        filteredProducts =
            max50Products
                .where((p) => options.selectedIds.contains(p.id))
                .toList();
      }

      if (filteredProducts.isEmpty) {
        AppSnackbar.show(
          context,
          message: 'No hay productos seleccionados para exportar.',
          type: SnackbarType.error,
        );
        return;
      }

      final productIds = filteredProducts.map((p) => p.id).toList();
      final variantsByProduct = await service.loadVariantsByProductIds(
        productIds,
      );
      final allVariantIds =
          variantsByProduct.values
              .expand((v) => v)
              .map((v) => v.id)
              .whereType<String>()
              .toList();
      final stockByVariant = await service.loadVariantStockByVariantIds(
        allVariantIds,
      );

      CatalogPdfGenerator.shareCatalog(
        products: filteredProducts,
        variantsByProduct: variantsByProduct,
        stockByVariant: stockByVariant,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo exportar el PDF: $e',
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) provider.setLoadingAction(false);
    }
  }

  Future<void> _toggleProductoActivo(
    ProductModel product,
    AdminCatalogProvider provider,
  ) async {
    if (provider.isLoadingAction) return;
    final willActivate = !product.isActive;

    final confirm = await CatalogDialogs.showToggleProductActiveDialog(
      context,
      product,
    );

    if (confirm == true) {
      provider.setLoadingAction(true);
      try {
        final service = CatalogService();
        await service.setProductActive(
          productId: product.id,
          isActive: willActivate,
        );
        if (mounted) {
          AppSnackbar.show(
            context,
            message:
                willActivate
                    ? 'Producto activado exitosamente'
                    : 'Producto desactivado exitosamente',
            type: willActivate ? SnackbarType.success : SnackbarType.warning,
          );
          await provider.refreshProducts();
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error: $e',
            type: SnackbarType.error,
          );
        }
      } finally {
        if (mounted) provider.setLoadingAction(false);
      }
    }
  }

  void _irAVenta(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminAddToCartSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminCatalogProvider>(
      builder: (context, provider, child) {
        return AdminLayout(
          title: 'Catálogo',
          showSettingsButton: true,
          settingsActions: [
            if (provider.filterIsActive == null ||
                provider.filterIsActive == true)
              const PopupMenuItem(
                value: 'filter_inactive',
                child: Text('Ver Inactivos'),
              ),
            if (provider.filterIsActive == null ||
                provider.filterIsActive == false)
              const PopupMenuItem(
                value: 'filter_all',
                child: Text('Ver Todos'),
              ),
            const PopupMenuItem(value: 'export', child: Text('Exportar')),
            const PopupMenuItem(
              value: 'sync',
              child: Text('Forzar Sincronización'),
            ),
          ],
          onSettingsSelected: (value) async {
            switch (value) {
              case 'filter_inactive':
                provider.setFilterIsActive(false);
                break;
              case 'filter_all':
                provider.setFilterIsActive(null);
                break;
              case 'export':
                await _exportCatalogPdf(provider);
                break;
              case 'sync':
                await provider.forceSync();
                if (context.mounted) {
                  AppSnackbar.show(
                    context,
                    message: 'Sincronización completada.',
                    type: SnackbarType.success,
                  );
                }
                break;
            }
          },
          body: Builder(
            builder: (context) {
              const double fabsBottomPadding = 54;

              final headerSliver = SliverToBoxAdapter(
                child: Column(
                  children: [
                    CatalogHeader(
                      searchController: _searchCtrl,
                      isExporting: provider.isLoadingAction,
                      onExport: () => _exportCatalogPdf(provider),
                      onSearchChanged: provider.setSearchTerm,
                      searchByIngredient: provider.searchByIngredient,
                      onToggleIngredientSearch:
                          provider.toggleSearchByIngredient,
                    ),
                    if (provider.isLoadingAction)
                      const LinearProgressIndicator(
                        color: AppColors.teal,
                        minHeight: 2,
                      ),
                  ],
                ),
              );

              final chipsSliver =
                  (provider.categories.isNotEmpty &&
                          !provider.searchByIngredient)
                      ? SliverToBoxAdapter(
                        child: CategoryChips(
                          categories: provider.categories,
                          selectedCategoryId: provider.selectedCategoryId,
                          onSelected: provider.setCategory,
                        ),
                      )
                      : null;

              if (provider.isLoading) {
                return RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: () async => provider.refreshProducts(),
                  child: CustomScrollView(
                    slivers: [
                      headerSliver,
                      if (chipsSliver != null) chipsSliver,
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 280,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => AppShimmer(
                              width: double.infinity,
                              height: double.infinity,
                              borderRadius: AppColors.radiusLg,
                            ),
                            childCount: AdminCatalogProvider.pageSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (provider.error != null && provider.products.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: () async => provider.refreshProducts(),
                  child: CustomScrollView(
                    slivers: [
                      headerSliver,
                      if (chipsSliver != null) chipsSliver,
                      SliverFillRemaining(
                        child: CatalogErrorState(message: provider.error!),
                      ),
                    ],
                  ),
                );
              }

              if (provider.products.isEmpty && !provider.isLoading) {
                return RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: () async => provider.refreshProducts(),
                  child: CustomScrollView(
                    slivers: [
                      headerSliver,
                      if (chipsSliver != null) chipsSliver,
                      SliverFillRemaining(
                        child: CatalogEmptyState(
                          searchByIngredient: provider.searchByIngredient,
                          searchTerm: provider.searchTerm,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.teal,
                onRefresh: () async => provider.refreshProducts(),
                child: CatalogGridScrollView(
                  products: provider.products,
                  pageSize: AdminCatalogProvider.pageSize,
                  currentPage: provider.currentPage,
                  onPageChanged: provider.setPage,
                  onSale: _irAVenta,
                  onToggleActive: (p) => _toggleProductoActivo(p, provider),
                  searchByIngredient: provider.searchByIngredient,
                  matchedIngredients: provider.matchedIngredients,
                  bottomPadding: fabsBottomPadding,
                  headerSliver: headerSliver,
                  chipsSliver: chipsSliver,
                  onEdit: (product) async {
                    final result = await context.push(
                      '/admin/product-form',
                      extra: {'productToEdit': product},
                    );
                    if (result == true) {
                      CatalogService.clearCache();
                      provider.refreshProducts();
                    }
                  },
                ),
              );
            },
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Consumer<PosProvider>(
                builder: (posContext, pos, child) {
                  if (pos.itemCount == 0) return const SizedBox.shrink();
                  return CatalogPosCartButton(
                    itemCount: pos.itemCount,
                    total: pos.totalAmount,
                    onTap: () async {
                      await context.push('/admin/pos-checkout');
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              CatalogAddProductFab(
                onTap: () async {
                  final result = await context.push('/admin/product-form');
                  if (result == true) {
                    CatalogService.clearCache();
                    provider.setPage(0);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
