import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_avatar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_badges.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/quick_view/product_quick_view_variant_card.dart';

/// Helper y Contenido de la Ficha Rápida del Producto (Slide-Over Desktop & Bottom Sheet Móvil).
class ProductQuickViewSheet {
  static void show(
    BuildContext context, {
    required ProductEntity product,
    required AdminCatalogCubit cubit,
    required VoidCallback onToggleActive,
    required VoidCallback onEdit,
    required VoidCallback onOpenFullDetail,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'QuickView',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(-8, 0),
                    ),
                  ],
                ),
                child: ProductQuickViewContent(
                  product: product,
                  cubit: cubit,
                  isSideSheet: true,
                  onToggleActive: onToggleActive,
                  onEdit: onEdit,
                  onOpenFullDetail: onOpenFullDetail,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim, secondaryAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ProductQuickViewContent(
              product: product,
              cubit: cubit,
              isSideSheet: false,
              onToggleActive: onToggleActive,
              onEdit: onEdit,
              onOpenFullDetail: onOpenFullDetail,
            ),
          );
        },
      );
    }
  }
}

/// Contenido visual interior de la Ficha Rápida del Producto.
class ProductQuickViewContent extends StatelessWidget {
  final ProductEntity product;
  final AdminCatalogCubit cubit;
  final bool isSideSheet;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onOpenFullDetail;

  const ProductQuickViewContent({
    super.key,
    required this.product,
    required this.cubit,
    required this.isSideSheet,
    required this.onToggleActive,
    required this.onEdit,
    required this.onOpenFullDetail,
  });

  @override
  Widget build(BuildContext context) {
    final variants = product.productVariants;
    final primaryImg = product.primaryImageUrl;
    final displayPrice = product.displaySalePrice;
    final unitCost = product.defaultVariant?.unitCost;
    final activeIngredient =
        (product.details['active_ingredient'] ??
                product.details['active_ingredients'] ??
                product.details['principio_activo'] ??
                product.details['formula'])
            ?.toString();

    return Column(
      children: [
        // Apple Drag Handle en móvil
        if (!isSideSheet)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ficha Rápida del Producto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Micro-píldora activo
              ProductStatusPill(
                isActive: product.isActive,
                onTap: onToggleActive,
                isDense: true,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Cerrar (Esc)',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Cuerpo con Scroll
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero de Producto
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Imagen
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          primaryImg != null && primaryImg.isNotEmpty
                              ? Image.network(
                                primaryImg,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (ctx, err, stack) =>
                                        ProductMonogramAvatar(
                                          name: product.name,
                                          size: 72,
                                        ),
                              )
                              : ProductMonogramAvatar(
                                name: product.name,
                                size: 72,
                              ),
                    ),
                    const SizedBox(width: 14),

                    // Título y Categoría
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.categoryName ?? 'Sin categoría',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ProductStockBadge(stock: product.totalStock),
                              const SizedBox(width: 6),
                              ProductTypeBadge(type: product.productType),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (activeIngredient != null &&
                    activeIngredient.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Principio Activo: $activeIngredient',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Banner de Disponibilidad Consolidada y Acceso a Inventario ──
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warehouse_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Disponibilidad Consolidada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              product.totalStock > 0
                                  ? '${product.totalStock} unidades en almacenes de la empresa'
                                  : 'Sin existencias en ningún almacén',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color:
                                    product.totalStock > 0
                                        ? AppColors.textPrimary
                                        : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/admin/inventory');
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 12),
                        label: const Text(
                          'Ver en Inventario',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Tarjeta de Métricas Financieras y Stock
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Precio Venta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Precio Venta',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayPrice != null
                                  ? 'S/ ${displayPrice.toStringAsFixed(2)}'
                                  : 'Sin precio',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 14),

                      // Costo Ref
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Costo Ref.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unitCost != null
                                  ? 'S/ ${unitCost.toStringAsFixed(2)}'
                                  : '-',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 14),

                      // Control de Lotes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lotes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.usesBatches ? 'Activo' : 'No usa',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    product.usesBatches
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Sección Variantes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.style_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Variantes (${variants.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (variants.length > 1)
                      Text(
                        'Total: ${product.totalStock} unid.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (variants.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Este producto no cuenta con variantes configuradas.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: variants.length,
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final v = variants[index];
                      return ProductQuickViewVariantCard(
                        variant: v,
                        index: index,
                        isSingleVariant: variants.length == 1,
                        productStock: product.totalStock,
                        batches: product.warehouseStockBatches,
                      );
                    },
                  ),

                if (product.description != null &&
                    product.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Footer con Acciones Clave
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Editar Producto',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenFullDetail,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Ver Ficha Completa',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
