import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_avatar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_badges.dart';

/// Listado de tarjetas flotantes para móvil estilo Apple / iOS Card-Based.
class ProductsMobileCardList extends StatelessWidget {
  final List<ProductEntity> products;
  final Map<String, String> matchedIngredients;
  final ScrollController scrollController;
  final void Function(ProductEntity product) onTapProduct;
  final void Function(ProductEntity product) onToggleActive;
  final void Function(ProductEntity product) onEdit;
  final void Function(ProductEntity product) onDelete;
  final void Function(ProductEntity product) onOpenFullDetail;

  const ProductsMobileCardList({
    super.key,
    required this.products,
    required this.matchedIngredients,
    required this.scrollController,
    required this.onTapProduct,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenFullDetail,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 84),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final activeIngredient = matchedIngredients[product.id];
        final variantCount = product.productVariants.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => onTapProduct(product),
            borderRadius: BorderRadius.circular(AppColors.radius),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.8),
                ),
                boxShadow: AppColors.cardShadow(opacity: 0.03),
              ),
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar / Monograma
                  ProductAvatar(product: product, size: 52),
                  const SizedBox(width: 14),

                  // Información Principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ProductStatusPill(
                              isActive: product.isActive,
                              isDense: true,
                              onTap: () => onToggleActive(product),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              product.categoryName ?? 'Sin categoría',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (variantCount > 1) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• $variantCount variantes',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (activeIngredient != null &&
                            activeIngredient.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            '⚗️ $activeIngredient',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ProductStockBadge(stock: product.totalStock),
                            const SizedBox(width: 6),
                            ProductTypeBadge(type: product.productType),
                            const Spacer(),
                            // Menú de opciones rápido para móvil
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              onSelected: (val) {
                                if (val == 'view') {
                                  onTapProduct(product);
                                } else if (val == 'full_detail') {
                                  onOpenFullDetail(product);
                                } else if (val == 'edit') {
                                  onEdit(product);
                                } else if (val == 'toggle') {
                                  onToggleActive(product);
                                } else if (val == 'delete') {
                                  onDelete(product);
                                }
                              },
                              itemBuilder:
                                  (ctx) => [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.visibility_outlined,
                                            size: 18,
                                            color: AppColors.textSecondary,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Vista Rápida y Variantes'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'full_detail',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.open_in_new_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Ver Ficha Completa'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: AppColors.textSecondary,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Editar Producto'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Row(
                                        children: [
                                          Icon(
                                            product.isActive
                                                ? Icons.hide_source_rounded
                                                : Icons
                                                    .check_circle_outline_rounded,
                                            size: 18,
                                            color:
                                                product.isActive
                                                    ? AppColors.warningDark
                                                    : AppColors.success,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            product.isActive
                                                ? 'Desactivar'
                                                : 'Activar',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.error,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Eliminar Producto',
                                            style: TextStyle(
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
