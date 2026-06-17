import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_catalog_screen/catalog_product_card.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

/// Grid paginado del catálogo admin con soporte responsive.
class CatalogGridScrollView extends StatelessWidget {
  final List<ProductModel> products;
  final int pageSize;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final void Function(ProductModel) onSale;
  final void Function(ProductModel) onToggleActive;
  final void Function(ProductModel) onEdit;
  final bool searchByIngredient;
  final Map<String, String> matchedIngredients;
  final double bottomPadding;
  final Widget topBarSliver;
  final Widget headerSliver;
  final Widget? chipsSliver;

  const CatalogGridScrollView({
    super.key,
    required this.products,
    required this.pageSize,
    required this.currentPage,
    required this.onPageChanged,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    required this.topBarSliver,
    required this.headerSliver,
    this.chipsSliver,
    this.searchByIngredient = false,
    this.matchedIngredients = const {},
    this.bottomPadding = 0,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double aspectRatio;

        if (constraints.maxWidth >= 1024) {
          crossAxisCount = 5;
          aspectRatio = 1.0;
        } else if (constraints.maxWidth >= 600) {
          crossAxisCount = 3;
          aspectRatio = 0.85;
        } else {
          crossAxisCount = 2;
          aspectRatio = 0.80;
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            topBarSliver,
            headerSliver,
            if (chipsSliver != null) chipsSliver!,
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      'Mostrando ${total == 0 ? 0 : start + 1}-$end de $total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Pág. ${safeCurrentPage + 1} / $totalPages',
                      style: const TextStyle(
                        fontSize: 12,
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: aspectRatio,
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
                    highlightIngredient:
                        searchByIngredient
                            ? matchedIngredients[product.id]
                            : null,
                  );
                }, childCount: pageItems.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomPadding),
                child: AdminPageBlocks(
                  currentPage: safeCurrentPage,
                  totalPages: totalPages,
                  onPageChanged: onPageChanged,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Alias de compatibilidad.
typedef CatalogGrid = CatalogGridScrollView;
