import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:inventory_store_app/providers/admin/admin_catalog_provider.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/services/admin/catalog_pdf_generator.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_header.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_product_skeleton.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/admin_add_to_cart_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_fab_buttons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Mostrar diálogo de carga bloqueante
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogCtx) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Generando Catálogo PDF...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
      );

      // Dar tiempo para que la animación del diálogo termine y el UI se pinte
      await Future.delayed(const Duration(milliseconds: 400));

      try {
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

        await CatalogPdfGenerator.shareCatalog(
          products: filteredProducts,
          variantsByProduct: variantsByProduct,
          stockByVariant: stockByVariant,
        );
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
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
    final service = CatalogService();

    provider.setLoadingAction(true);
    try {
      await service.setProductActive(
        productId: product.id,
        isActive: willActivate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              willActivate
                  ? '${product.name} ha sido activado'
                  : '${product.name} ha sido desactivado',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () async {
                provider.setLoadingAction(true);
                try {
                  await service.setProductActive(
                    productId: product.id,
                    isActive: !willActivate,
                  );
                  if (mounted) await provider.refreshProducts();
                } catch (_) {
                } finally {
                  if (mounted) provider.setLoadingAction(false);
                }
              },
            ),
          ),
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

  Future<void> _irAVenta(ProductModel product) async {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (!mounted) return;

    if (isDesktop) {
      showDialog(
        context: context,
        builder:
            (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 750,
                ),
                child: AdminAddToCartSheet(product: product),
              ),
            ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AdminAddToCartSheet(product: product),
      );
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(AdminCatalogProvider provider) {
    return [
      const PopupMenuItem(value: 'export', child: Text('Exportar')),
      const PopupMenuItem(value: 'sync', child: Text('Forzar Sincronización')),
    ];
  }

  Future<void> _handleMenuSelection(
    String value,
    AdminCatalogProvider provider,
    BuildContext ctx,
  ) async {
    switch (value) {
      case 'export':
        await _exportCatalogPdf(provider);
        break;
      case 'sync':
        await provider.forceSync();
        if (ctx.mounted) {
          AppSnackbar.show(
            ctx,
            message: 'Sincronización completada.',
            type: SnackbarType.success,
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        return Consumer<AdminCatalogProvider>(
          builder: (context, provider, child) {
            Widget buildBody() {
              return Builder(
                builder: (context) {
                  const double fabsBottomPadding = 54;

                  Widget mainContent = Builder(
                    builder: (context) {
                      final topBarSliver = SliverAppBar(
                        systemOverlayStyle: const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.dark,
                          statusBarBrightness: Brightness.light,
                        ),
                        backgroundColor: const Color(0xFFF7F8FC),
                        elevation: 0,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        surfaceTintColor: Colors.transparent,
                        titleSpacing: 0,
                        floating: true,
                        pinned: false,
                        title: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'Catálogo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        leadingWidth: 60,
                        leading: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 12),
                              AdminProfileAvatar(
                                onTap: () {
                                  final user =
                                      Supabase.instance.client.auth.currentUser;
                                  if (user == null) {
                                    context.go('/login');
                                  } else {
                                    context.push('/admin/profile');
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          if (MediaQuery.of(context).size.width >= 900)
                            ElevatedButton.icon(
                              onPressed: () => context.push('/admin/pos'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(
                                Icons.point_of_sale_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Abrir Caja',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          AdminSettingsMenuButton(
                            items: _buildMenuItems(provider),
                            onSelected:
                                (value) => _handleMenuSelection(
                                  value,
                                  provider,
                                  context,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder:
                                (context) => AdminAppBarIconButton(
                                  icon: Icons.menu_rounded,
                                  onTap:
                                      () =>
                                          Scaffold.of(context).openEndDrawer(),
                                ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      );

                      // Header colapsable: se reduce a solo el search bar al scrollear
                      final isDesktop =
                          MediaQuery.of(context).size.width >= 900;

                      double headerMaxHeight;
                      if (isDesktop) {
                        headerMaxHeight =
                            provider.searchByIngredient ? 120.0 : 70.0;
                      } else {
                        headerMaxHeight =
                            provider.searchByIngredient ? 175.0 : 115.0;
                      }
                      const double headerMinHeight = 60.0;

                      final headerSliver = SliverPersistentHeader(
                        pinned: true,
                        delegate: _CatalogHeaderDelegate(
                          minHeight: headerMinHeight,
                          maxHeight: headerMaxHeight,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 12.0,
                                sigmaY: 12.0,
                              ),
                              child: Container(
                                color: const Color(
                                  0xFFF9FAFB,
                                ).withValues(alpha: 0.85),
                                child: OverflowBox(
                                  alignment: Alignment.topCenter,
                                  maxHeight: double.infinity,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CatalogHeader(
                                        searchController: _searchCtrl,
                                        isExporting: provider.isLoadingAction,
                                        onExport:
                                            () => _exportCatalogPdf(provider),
                                        onSearchChanged: provider.setSearchTerm,
                                        searchByIngredient:
                                            provider.searchByIngredient,
                                        onToggleIngredientSearch:
                                            provider.toggleSearchByIngredient,
                                        onAddProduct:
                                            () => context.push(
                                              '/admin/product-form',
                                            ),
                                      ),
                                      if (provider.isLoadingAction)
                                        const LinearProgressIndicator(
                                          color: AppColors.teal,
                                          minHeight: 2,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );

                      final chipsSliver =
                          (provider.categories.isNotEmpty &&
                                  !provider.searchByIngredient)
                              ? SliverToBoxAdapter(
                                child: CategoryChips(
                                  categories: provider.categories,
                                  selectedCategoryId:
                                      provider.selectedCategoryId,
                                  onSelected: provider.setCategory,
                                  filterIsActive: provider.filterIsActive,
                                  onStatusSelected: provider.setFilterIsActive,
                                ),
                              )
                              : null;

                      if (provider.isLoading) {
                        return RefreshIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          onRefresh: () async => provider.refreshProducts(),
                          child: CustomScrollView(
                            slivers: [
                              topBarSliver,
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
                                    (context, index) =>
                                        const AdminProductSkeleton(),
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
                          color: Theme.of(context).colorScheme.primary,
                          onRefresh: () async => provider.refreshProducts(),
                          child: CustomScrollView(
                            slivers: [
                              topBarSliver,
                              headerSliver,
                              if (chipsSliver != null) chipsSliver,
                              SliverFillRemaining(
                                child: CatalogErrorState(
                                  message: provider.error!,
                                  onRetry: () => provider.refreshProducts(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (provider.products.isEmpty && !provider.isLoading) {
                        return RefreshIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          onRefresh: () async => provider.refreshProducts(),
                          child: CustomScrollView(
                            slivers: [
                              topBarSliver,
                              headerSliver,
                              if (chipsSliver != null) chipsSliver,
                              SliverFillRemaining(
                                child: CatalogEmptyState(
                                  searchByIngredient:
                                      provider.searchByIngredient,
                                  searchTerm: provider.searchTerm,
                                  onRetry: () {
                                    if (provider.searchTerm.isNotEmpty) {
                                      _searchCtrl.clear();
                                      provider.setSearchTerm('');
                                    } else {
                                      provider.refreshProducts();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: Theme.of(context).colorScheme.primary,
                        onRefresh: () async => provider.refreshProducts(),
                        child: CatalogGridScrollView(
                          products: provider.products,
                          pageSize: AdminCatalogProvider.pageSize,
                          currentPage: provider.currentPage,
                          onPageChanged: provider.setPage,
                          onSale: _irAVenta,
                          onToggleActive:
                              (p) => _toggleProductoActivo(p, provider),
                          searchByIngredient: provider.searchByIngredient,
                          matchedIngredients: provider.matchedIngredients,
                          bottomPadding: fabsBottomPadding,
                          topBarSliver: topBarSliver,
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
                          isPosMode: false,
                        ),
                      );
                    },
                  );

                  Widget catalogBody = Column(
                    children: [
                      Expanded(child: mainContent),
                      if (provider.products.isNotEmpty &&
                          provider.totalPages > 1)
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
                              currentPage: provider.currentPage,
                              totalPages: provider.totalPages,
                              onPageChanged: provider.setPage,
                            ),
                          ),
                        ),
                    ],
                  );

                  if (isDesktop) {
                    return Container(
                      color: const Color(0xFFF9FAFB),
                      child: catalogBody,
                    );
                  }

                  return catalogBody;
                },
              );
            }

            final floatingBtn =
                isDesktop
                    ? null
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Consumer<PosProvider>(
                          builder: (posContext, pos, child) {
                            if (pos.itemCount == 0) {
                              return const SizedBox.shrink();
                            }
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
                            final result = await context.push(
                              '/admin/product-form',
                            );
                            if (result == true) {
                              CatalogService.clearCache();
                              provider.setPage(0);
                            }
                          },
                        ),
                      ],
                    );

            final bodyContent = buildBody();

            return AdminLayout(
              title: 'Catálogo',
              showSettingsButton: true,
              settingsActions: _buildMenuItems(provider),
              onSettingsSelected:
                  (value) => _handleMenuSelection(value, provider, context),
              showAppBar: false,
              body: bodyContent,
              floatingActionButton: floatingBtn,
            );
          },
        );
      },
    );
  }
}

class _CatalogHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _CatalogHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
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
        child != oldDelegate.child;
  }
}
