import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_category_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_grid_view.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_header.dart';

extension ProductToCartExtension on ProductEntity {
  CartItemEntity toCartItem({int? warehouseStock}) {
    final variant = defaultVariant;
    final cartKey = variant?.id ?? id;
    final effectiveStock = warehouseStock ?? totalStock;
    return CartItemEntity(
      productId: id,
      productName: name,
      cartKey: cartKey,
      variantId: variant?.id,
      variantLabel: variant?.label,
      quantity: 1,
      unitPrice: displaySalePrice ?? 0.0,
      unitCost: variant?.unitCost ?? 0.0,
      availableStock:
          stockControl ? effectiveStock : CartItemEntity.unlimitedStock,
      usesBatches: usesBatches,
      wholesalePrice: variant?.wholesalePrice,
      sku: variant?.sku,
      imageUrl: primaryImageUrl,
      isSelected: true,
    );
  }
}

class PosCatalogView extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onScanBarcode;
  final VoidCallback? onExitPos;
  final bool isCashierOnly;
  final ValueChanged<ProductEntity> onSale;

  const PosCatalogView({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onScanBarcode,
    required this.onExitPos,
    required this.isCashierOnly,
    required this.onSale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocSelector<PosCubit, PosState, String?>(
            selector: (posState) => posState.selectedWarehouseId,
            builder: (context, selectedWarehouseId) {
              return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                buildWhen:
                    (prev, current) =>
                        prev.products != current.products ||
                        prev.catalogState != current.catalogState ||
                        prev.errorMessage != current.errorMessage,
                builder:
                    (context, state) => _buildMainContent(
                      context,
                      context.read<AdminCatalogCubit>(),
                      state,
                      warehouseId: selectedWarehouseId,
                      headerSliver: _buildCatalogHeaderSliver(context),
                      chipsSliver: _buildCategoryChipsSliver(context),
                    ),
              );
            },
          ),
        ),
        BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
          buildWhen:
              (prev, current) =>
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
  }

  Widget _buildCatalogHeaderSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: BlocSelector<AdminCatalogCubit, AdminCatalogState, bool>(
          selector: (state) => state.searchByIngredient,
          builder: (context, searchByIngredient) {
            return PosHeader(
              searchController: searchController,
              searchFocusNode: searchFocusNode,
              onSearchChanged: onSearchChanged,
              searchByIngredient: searchByIngredient,
              onToggleIngredientSearch:
                  context.read<AdminCatalogCubit>().toggleSearchByIngredient,
              onScanBarcode: onScanBarcode,
              onBack: isCashierOnly ? null : onExitPos,
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChipsSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
        buildWhen:
            (prev, current) =>
                prev.categories != current.categories ||
                prev.selectedCategoryId != current.selectedCategoryId ||
                prev.brands != current.brands ||
                prev.selectedBrandId != current.selectedBrandId ||
                prev.filterIsActive != current.filterIsActive ||
                prev.sortOption != current.sortOption ||
                prev.stockFilter != current.stockFilter,
        builder: (context, state) {
          if (state.categories.isEmpty && state.brands.isEmpty) {
            return const SizedBox.shrink();
          }
          return Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CategoryChips(
              categories: state.categories,
              selectedCategoryId: state.selectedCategoryId,
              onSelected: context.read<AdminCatalogCubit>().setCategory,
              brands: state.brands,
              selectedBrandId: state.selectedBrandId,
              onBrandSelected: context.read<AdminCatalogCubit>().setBrand,
              filterIsActive: state.filterIsActive,
              showStatusFilter: false,
              sortOption: state.sortOption,
              onSortSelected: context.read<AdminCatalogCubit>().setSortOption,
              stockFilter: state.stockFilter,
              onStockFilterSelected:
                  context.read<AdminCatalogCubit>().setStockFilter,
              onClearAllFilters: () {
                final cubit = context.read<AdminCatalogCubit>();
                cubit.setCategory(null);
                cubit.setBrand(null);
                cubit.setStockFilter(CatalogStockFilter.all);
                cubit.setSortOption(CatalogSortOption.recent);
                cubit.setFilterIsActive(true);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AdminCatalogCubit cubit,
    AdminCatalogState state, {
    String? warehouseId,
    required Widget headerSliver,
    required Widget chipsSliver,
  }) {
    if ((state.catalogState == ViewState.loading) && state.products.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          headerSliver,
          chipsSliver,
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
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
              delegate: SliverChildBuilderDelegate((context, index) {
                return const AppShimmer(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 16,
                );
              }, childCount: 12),
            ),
          ),
        ],
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          headerSliver,
          chipsSliver,
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CatalogErrorState(message: state.errorMessage!),
            ),
          ),
        ],
      );
    }

    if (state.products.isEmpty && !(state.catalogState == ViewState.loading)) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          headerSliver,
          chipsSliver,
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CatalogEmptyState(
                searchByIngredient: state.searchByIngredient,
                searchTerm: state.searchTerm,
              ),
            ),
          ),
        ],
      );
    }

    return CatalogGridScrollView(
      products: state.products,
      pageSize: AdminCatalogState.pageSize,
      currentPage: state.currentPage,
      totalCount: state.totalCount,
      onPageChanged: cubit.setPage,
      onSale: onSale,
      onToggleActive: (p) => Future.value(),
      searchByIngredient: state.searchByIngredient,
      matchedIngredients: state.matchedIngredients,
      bottomPadding: MediaQuery.of(context).size.width >= 800 ? 24 : 100,
      isPosMode: true,
      warehouseId: warehouseId,
      onEdit: (product) {},
      headerSliver: headerSliver,
      chipsSliver: chipsSliver,
    );
  }
}
