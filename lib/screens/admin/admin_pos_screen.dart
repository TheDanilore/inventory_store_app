import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_store_app/providers/admin/admin_catalog_provider.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/data/admin/products_repository.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_header.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/admin_add_to_cart_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/screens/admin/widgets/pos_checkout/desktop_pos_panel.dart';

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
      final provider = context.read<AdminCatalogProvider>();
      _searchCtrl.text = provider.searchTerm;
      // Removido provider.refreshProducts() para evitar lag.
      // El POS usa la data ya cacheada por AdminCatalogScreen.
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _irAVenta(ProductModel product) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final repo = ProductsRepository();
      final variantsMap = await repo.fetchVariantsByProductIds([product.id]);
      final variants = variantsMap[product.id] ?? [];

      if (!mounted) return;
      Navigator.pop(context); // cerrar loader

      if (variants.isEmpty || variants.length == 1) {
        final variant = variants.isNotEmpty ? variants.first : null;
        int stock = 0;

        if (product.stockControl) {
          if (variant != null) {
            final stockMap = await repo.fetchVariantStockByVariantIds([
              variant.id,
            ]);
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

    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
              child: AdminAddToCartSheet(product: product),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 150,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 4),
          child: TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            label: const Text(
              'Catálogo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: const Text(
          'CAJA POS',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Consumer<AdminCatalogProvider>(
        builder: (context, provider, child) {
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
                      isExporting: provider.isLoadingAction,
                      onExport: () {},
                      onSearchChanged: provider.setSearchTerm,
                      searchByIngredient: provider.searchByIngredient,
                      onToggleIngredientSearch:
                          provider.toggleSearchByIngredient,
                      onAddProduct: () async {
                        final result = await context.push(
                          '/admin/product-form',
                        );
                        if (result == true) {
                          provider.refreshProducts();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (provider.categories.isNotEmpty)
                      CategoryChips(
                        categories: provider.categories,
                        selectedCategoryId: provider.selectedCategoryId,
                        onSelected: provider.setCategory,
                        filterIsActive: provider.filterIsActive,
                        onStatusSelected: provider.setFilterIsActive,
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildMainContent(provider)),
            ],
          );

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
                    provider.refreshProducts();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(AdminCatalogProvider provider) {
    if (provider.isLoading && provider.products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.error != null && provider.products.isEmpty) {
      return Center(child: CatalogErrorState(message: provider.error!));
    }

    if (provider.products.isEmpty && !provider.isLoading) {
      return Center(
        child: CatalogEmptyState(
          searchByIngredient: provider.searchByIngredient,
          searchTerm: provider.searchTerm,
        ),
      );
    }

    return CatalogGridScrollView(
      products: provider.products,
      pageSize: AdminCatalogProvider.pageSize,
      currentPage: provider.currentPage,
      onPageChanged: provider.setPage,
      onSale: _irAVenta,
      onToggleActive:
          (p) => Future.value(), // No permitimos editar en modo caja
      searchByIngredient: provider.searchByIngredient,
      matchedIngredients: provider.matchedIngredients,
      bottomPadding: 24,
      isPosMode: true,
      onEdit: (product) {}, // No permitimos editar en modo caja
    );
  }
}
