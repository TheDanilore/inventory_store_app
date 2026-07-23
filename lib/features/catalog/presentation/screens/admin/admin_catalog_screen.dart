import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_header.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_product_skeleton.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_fab_buttons.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_add_to_cart_sheet.dart';

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
    super.dispose();
  }

  Future<void> _toggleProductoActivo(
    ProductEntity product,
    AdminCatalogCubit cubit,
  ) async {
    final willActivate = !product.isActive;

    final success = await cubit.toggleProductActive(product);

    if (success && mounted) {
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
              await cubit.toggleProductActive(
                product.copyWith(isActive: willActivate),
              );
            },
          ),
        ),
      );
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(AdminCatalogState state) {
    return [
      const PopupMenuItem(value: 'export', child: Text('Exportar')),
      const PopupMenuItem(value: 'sync', child: Text('Forzar Sincronización')),
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
        await cubit.refreshProducts();
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
      builder:
          (_) => const AlertDialog(
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
        final isDesktop = constraints.maxWidth >= 900;
        return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
          builder: (context, state) {
            final cubit = context.read<AdminCatalogCubit>();
            Widget buildBody() {
              return Builder(
                builder: (context) {
                  const double fabsBottomPadding = 54;

                  Widget mainContent = Builder(
                    builder: (context) {
                      // Removed SliverAppBar as it will be managed by AdminLayout

                      // Header colapsable: se reduce a solo el search bar al scrollear
                      final isDesktop =
                          MediaQuery.of(context).size.width >= 900;

                      double headerMaxHeight;
                      if (isDesktop) {
                        headerMaxHeight =
                            state.searchByIngredient ? 115.0 : 64.0;
                      } else {
                        headerMaxHeight =
                            state.searchByIngredient ? 115.0 : 64.0;
                      }
                      const double headerMinHeight = 64.0;

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
                                        isExporting:
                                            state.actionState ==
                                            ViewState.loading,
                                        onExport:
                                            () => _exportCatalogPdf(
                                              context,
                                              cubit,
                                              state,
                                            ),
                                        onSearchChanged: cubit.setSearchTerm,
                                        searchByIngredient:
                                            state.searchByIngredient,
                                        onToggleIngredientSearch:
                                            cubit.toggleSearchByIngredient,
                                        onAddProduct:
                                            () => context.go(
                                              '/admin/product-form',
                                            ),
                                      ),
                                      if (state.actionState ==
                                          ViewState.loading)
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
                          (state.categories.isNotEmpty &&
                                  !state.searchByIngredient)
                              ? SliverToBoxAdapter(
                                child: CategoryChips(
                                  categories: state.categories,
                                  selectedCategoryId: state.selectedCategoryId,
                                  onSelected: cubit.setCategory,
                                  filterIsActive: state.filterIsActive,
                                  onStatusSelected: cubit.setFilterIsActive,
                                ),
                              )
                              : null;

                      if (state.catalogState == ViewState.loading ||
                          state.catalogState == ViewState.initial) {
                        return RefreshIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          onRefresh: () async => cubit.refreshProducts(),
                          child: CustomScrollView(
                            slivers: [
                              headerSliver,
                              if (chipsSliver != null) chipsSliver,
                              SliverPadding(
                                padding: const EdgeInsets.all(16),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 300,
                                        mainAxisExtent: 280,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) =>
                                        const AdminProductSkeleton(),
                                    childCount: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (state.errorMessage != null &&
                          state.products.isEmpty) {
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
                                      cubit.setSearchTerm('');
                                    } else {
                                      cubit.refreshProducts();
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
                        onRefresh: () async => cubit.refreshProducts(),
                        child: CatalogGridScrollView(
                          products: state.products,
                          pageSize: 20,
                          currentPage: state.currentPage,
                          onPageChanged: cubit.setPage,
                          onSale:
                              widget.onAddToCart ??
                              (product) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder:
                                      (_) => Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              MediaQuery.of(
                                                context,
                                              ).viewInsets.bottom,
                                        ),
                                        child: PosAddToCartSheet(
                                          productEntity: product,
                                        ),
                                      ),
                                );
                              },
                          onToggleActive:
                              (p) => _toggleProductoActivo(p, cubit),
                          searchByIngredient: state.searchByIngredient,
                          matchedIngredients: state.matchedIngredients,
                          bottomPadding: fabsBottomPadding,
                          headerSliver: headerSliver,
                          chipsSliver: chipsSliver,
                          onEdit: (product) async {
                            final result = await context.push(
                              '/admin/product-form',
                              extra: {'productToEdit': product},
                            );
                            if (result == true) {
                              await cubit.refreshProducts();
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

                  if (isDesktop) {
                    return Container(
                      color: AppColors.background,
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
                        if (widget.floatingActionButton != null)
                          widget.floatingActionButton!,
                        const SizedBox(height: 12),
                        CatalogAddProductFab(
                          onTap: () async {
                            final result = await context.push(
                              '/admin/product-form',
                            );
                            if (result == true) {
                              await cubit.refreshProducts();
                            }
                          },
                        ),
                      ],
                    );

            final bodyContent = buildBody();

            return AdminLayout(
              title: 'Catálogo',
              showSettingsButton: true,
              settingsActions: _buildMenuItems(state),
              onSettingsSelected:
                  (value) => _handleMenuSelection(value, cubit, state, context),
              showAppBar: true,
              actions: [
                if (isDesktop)
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/pos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                      'Abrir Caja',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
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
        minHeight != oldDelegate.minHeight;
  }
}
