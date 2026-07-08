import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/widgets/admin_catalog_screen/catalog_product_card.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Grid paginado del catálogo admin con soporte responsive.
class CatalogGridScrollView extends StatelessWidget {
  final List<ProductModel> products;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final void Function(ProductModel) onSale;
  final Future<void> Function(ProductModel) onToggleActive;
  final void Function(ProductModel) onEdit;
  final bool searchByIngredient;
  final Map<String, String> matchedIngredients;
  final double bottomPadding;
  final Widget? topBarSliver;
  final Widget? headerSliver;
  final Widget? chipsSliver;
  final bool isPosMode;

  const CatalogGridScrollView({
    super.key,
    required this.products,
    required this.pageSize,
    required this.currentPage,
    required this.onPageChanged,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    this.topBarSliver,
    this.headerSliver,
    this.chipsSliver,
    this.searchByIngredient = false,
    this.matchedIngredients = const {},
    this.bottomPadding = 0,
    this.isPosMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = products.length;
    final totalPages = total == 0 ? 1 : (total / pageSize).ceil();
    final safeCurrentPage =
        currentPage >= totalPages ? totalPages - 1 : currentPage;
    final start = safeCurrentPage * pageSize;
    final end = (start + pageSize) > total ? total : (start + pageSize);
    final pageItems = products.sublist(start, end);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (topBarSliver != null) topBarSliver!,
        if (headerSliver != null) headerSliver!,
        if (chipsSliver != null) chipsSliver!,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Mostrando ${total == 0 ? 0 : start + 1}-$end de $total',
                  style: const TextStyle(
                    fontSize: 13, // Aumentado a 13px (prominente)
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Pág. ${safeCurrentPage + 1} / $totalPages',
                  style: const TextStyle(
                    fontSize: 11, // Reducido a 11px (secundario)
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 280,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final product = pageItems[index];
              return AdminProductCard(
                product: product,
                onSale: () => onSale(product),
                onToggleActive: () => onToggleActive(product),
                onEdit: () => onEdit(product),
                isFullPosMode: isPosMode,
                highlightIngredient:
                    searchByIngredient ? matchedIngredients[product.id] : null,
              );
            }, childCount: pageItems.length),
          ),
        ),
        // La paginación (AdminPageBlocks) fue extraída a la pantalla principal
        // para estar anclada abajo fuera del scroll.
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }
}

/// Alias de compatibilidad.
typedef CatalogGrid = CatalogGridScrollView;
