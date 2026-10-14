import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_avatar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_badges.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/quick_view/product_quick_view_variant_card.dart';

/// Ficha Rápida del Producto. El contorno (slide-over / bottom sheet) lo
/// resuelve [AdaptiveDetailSheet]; aquí solo vive el contenido.
class ProductQuickViewSheet {
  static void show(
    BuildContext context, {
    required ProductEntity product,
    required AdminCatalogCubit cubit,
    required VoidCallback onToggleActive,
    required VoidCallback onEdit,
    required VoidCallback onOpenFullDetail,
  }) {
    AdaptiveDetailSheet.show(
      context,
      wrap: (child) => BlocProvider.value(value: cubit, child: child),
      builder:
          (_) => ProductQuickViewContent(
            product: product,
            onToggleActive: onToggleActive,
            onEdit: onEdit,
            onOpenFullDetail: onOpenFullDetail,
          ),
    );
  }
}

class ProductQuickViewContent extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onOpenFullDetail;

  const ProductQuickViewContent({
    super.key,
    required this.product,
    required this.onToggleActive,
    required this.onEdit,
    required this.onOpenFullDetail,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
      buildWhen: (a, b) => a.products != b.products,
      builder: (context, state) {
        final p =
            state.products.where((x) => x.id == product.id).firstOrNull ??
            product;
        return _buildFrame(context, p);
      },
    );
  }

  Widget _buildFrame(BuildContext context, ProductEntity p) {
    final variants = p.productVariants;
    final img = p.primaryImageUrl;
    final price = p.displaySalePrice;
    final cost = p.defaultVariant?.unitCost;
    final isSimple =
        variants.length == 1 && variants.first.attributeValues.isEmpty;

    final activeIngredient =
        (p.details['active_ingredient'] ??
                p.details['active_ingredients'] ??
                p.details['principio_activo'] ??
                p.details['formula'])
            ?.toString();

    String margin = '-';
    Color? marginColor;
    if (price != null && cost != null && price > 0) {
      final pct = ((price - cost) / price) * 100;
      margin = '${pct.toStringAsFixed(0)}%';
      marginColor = pct >= 0 ? AppColors.successDark : AppColors.danger;
    }

    return DetailSheetFrame(
      title: p.name,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child:
            (img != null && img.isNotEmpty)
                ? Image.network(
                  img,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) =>
                          ProductMonogramAvatar(name: p.name, size: 52),
                )
                : ProductMonogramAvatar(name: p.name, size: 52),
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            p.categoryName ?? 'Sin categoría',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          ProductStatusPill(
            isActive: p.isActive,
            onTap: onToggleActive,
            isDense: true,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ProductStockBadge(stock: p.totalStock),
              ProductTypeBadge(type: p.productType),
              if (p.usesBatches) const _MiniTag('Control por lotes'),
            ],
          ),

          if (activeIngredient != null && activeIngredient.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              icon: Icons.science_outlined,
              text: 'Principio activo: $activeIngredient',
              color: AppColors.accent,
            ),
          ],

          const SizedBox(height: 14),
          // Métrica con desglose limpio
          DetailSectionCard(
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _MetricItem(
                      label: 'Precio venta',
                      value:
                          price != null
                              ? 'S/ ${price.toStringAsFixed(2)}'
                              : '—',
                      emphasized: true,
                    ),
                  ),
                  const VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _MetricItem(
                      label: 'Costo ref.',
                      value:
                          cost != null ? 'S/ ${cost.toStringAsFixed(2)}' : '—',
                      valueColor: AppColors.textSecondary,
                    ),
                  ),
                  const VerticalDivider(
                    width: 24,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _MetricItem(
                      label: 'Margen',
                      value: margin,
                      valueColor: marginColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          DetailSectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.warehouse_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disponibilidad consolidada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.totalStock > 0
                            ? '${p.totalStock} unidades en almacenes'
                            : 'Sin existencias en ningún almacén',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              p.totalStock > 0
                                  ? AppColors.textPrimary
                                  : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final q = Uri.encodeComponent(p.name.trim());
                    context.push('/inventory?search=$q');
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Inventario',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_outward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          DetailSectionCard(
            title: isSimple ? 'Presentación' : 'Variantes (${variants.length})',
            icon: isSimple ? Icons.inventory_2_outlined : Icons.style_outlined,
            trailing:
                variants.length > 1
                    ? Text(
                      'Total: ${p.totalStock} unid.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealDark,
                      ),
                    )
                    : null,
            child:
                variants.isEmpty
                    ? const Text(
                      'Este producto no tiene variantes configuradas.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    )
                    : Column(
                      children: [
                        for (var i = 0; i < variants.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          ProductQuickViewVariantCard(
                            variant: variants[i],
                            productName: p.name,
                            index: i,
                            isSingleVariant: variants.length == 1,
                            productStock: p.totalStock,
                            batches: p.warehouseStockBatches,
                          ),
                        ],
                      ],
                    ),
          ),

          if (p.description != null && p.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            DetailSectionCard(
              title: 'Descripción',
              child: Text(
                p.description!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onEdit();
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onOpenFullDetail();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Ver ficha completa'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasized;

  const _MetricItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: emphasized ? 17 : 14.5,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  const _MiniTag(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}
