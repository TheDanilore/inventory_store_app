import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_product_card.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Grid paginado del catálogo admin con soporte responsive.
class CatalogGridScrollView extends StatelessWidget {
  final List<ProductEntity> products;
  final int pageSize;
  final int currentPage;
  final int? totalCount;
  final ValueChanged<int> onPageChanged;
  final void Function(ProductEntity) onSale;
  final Future<void> Function(ProductEntity) onToggleActive;
  final void Function(ProductEntity) onEdit;
  final void Function(ProductEntity)? onProductTap;
  final bool searchByIngredient;
  final Map<String, String> matchedIngredients;
  final double bottomPadding;
  final Widget? headerSliver;
  final Widget? chipsSliver;
  final bool isPosMode;
  final String? selectedProductId;

  const CatalogGridScrollView({
    super.key,
    required this.products,
    required this.pageSize,
    required this.currentPage,
    this.totalCount,
    required this.onPageChanged,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    this.onProductTap,
    this.headerSliver,
    this.chipsSliver,
    this.searchByIngredient = false,
    this.matchedIngredients = const {},
    this.bottomPadding = 0,
    this.isPosMode = false,
    this.selectedProductId,
  });

  @override
  Widget build(BuildContext context) {
    // Si totalCount está disponible (remoto de Supabase), usarlo; de lo contrario fallback a products.length
    final effectiveTotal = totalCount ?? products.length;
    final totalPages = effectiveTotal == 0 ? 1 : (effectiveTotal / pageSize).ceil();
    final start = effectiveTotal == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = math.min((currentPage + 1) * pageSize, effectiveTotal);
    final pageItems = products;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (headerSliver != null) headerSliver!,
        if (chipsSliver != null) chipsSliver!,
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Mostrando ${effectiveTotal == 0 ? 0 : start}-$end de $effectiveTotal',
                  style: const TextStyle(
                    fontSize: 13, // Aumentado a 13px (prominente)
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Pág. ${effectiveTotal == 0 ? 1 : currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    fontSize: 11, // Reducido a 11px (secundario)
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Builder(
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            final double maxExtent = isPosMode
                ? (screenWidth < 500 ? 170 : (screenWidth < 900 ? 190 : 210))
                : (screenWidth < 500 ? 210 : (screenWidth < 900 ? 260 : 300));
            final double mainExtent = isPosMode
                ? (screenWidth < 500 ? 205 : 215)
                : (screenWidth < 500 ? 272 : 280);

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  mainAxisExtent: mainExtent,
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
                    onTap: onProductTap != null ? () => onProductTap!(product) : null,
                    isFullPosMode: isPosMode,
                    isSelected: selectedProductId == product.id,
                    highlightIngredient:
                        searchByIngredient ? matchedIngredients[product.id] : null,
                  );
                }, childCount: pageItems.length),
              ),
            );
          },
        ),
        if (totalPages > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow(opacity: 0.03),
                ),
                child: AdminPageBlocks(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: onPageChanged,
                  totalItems: effectiveTotal,
                  itemsPerPage: pageSize,
                  itemName: 'productos',
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding + 16)),
      ],
    );
  }
}

/// Alias de compatibilidad.
typedef CatalogGrid = CatalogGridScrollView;
