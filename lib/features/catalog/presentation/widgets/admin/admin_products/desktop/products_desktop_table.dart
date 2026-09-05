import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_avatar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_badges.dart';

/// Data-Grid Pro de escritorio de alta densidad para productos.
class ProductsDesktopTable extends StatelessWidget {
  final List<ProductEntity> products;
  final Set<String> selectedProductIds;
  final Map<String, String> matchedIngredients;
  final void Function(String productId, bool selected) onProductSelected;
  final void Function(bool selectAll) onSelectAllPage;
  final void Function(ProductEntity product) onRowTap;
  final void Function(ProductEntity product) onToggleActive;
  final void Function(ProductEntity product) onEdit;
  final void Function(ProductEntity product) onDelete;

  const ProductsDesktopTable({
    super.key,
    required this.products,
    required this.selectedProductIds,
    required this.matchedIngredients,
    required this.onProductSelected,
    required this.onSelectAllPage,
    required this.onRowTap,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final allPageSelected =
        products.isNotEmpty &&
        products.every((p) => selectedProductIds.contains(p.id));
    final somePageSelected =
        products.any((p) => selectedProductIds.contains(p.id)) &&
        !allPageSelected;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(
                AppColors.background.withValues(alpha: 0.6),
              ),
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              columnSpacing: 20,
              horizontalMargin: 16,
              showBottomBorder: true,
              columns: [
                // Columna Selección Masiva
                DataColumn(
                  label: Checkbox(
                    value:
                        allPageSelected
                            ? true
                            : (somePageSelected ? null : false),
                    tristate: true,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) => onSelectAllPage(!allPageSelected),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'PRODUCTO',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'CATEGORÍA',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'TIPO',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Tooltip(
                    message: 'Disponibilidad consolidada en todos los almacenes',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'STOCK TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'ESTADO',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    'ACCIONES',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              rows:
                  products.map((product) {
                    final isSelected = selectedProductIds.contains(product.id);
                    final activeIngredient = matchedIngredients[product.id];
                    final variantCount = product.productVariants.length;

                    return DataRow(
                      selected: isSelected,
                      color: WidgetStateProperty.resolveWith<Color?>((
                        Set<WidgetState> states,
                      ) {
                        if (isSelected) {
                          return AppColors.primary.withValues(alpha: 0.06);
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return AppColors.primary.withValues(alpha: 0.025);
                        }
                        return null;
                      }),
                      onSelectChanged: (_) => onRowTap(product),
                      cells: [
                        // Checkbox individual
                        DataCell(
                          Checkbox(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged:
                                (val) =>
                                    onProductSelected(product.id, val == true),
                          ),
                        ),

                        // Celda Producto con Avatar y Variantes
                        DataCell(
                          InkWell(
                            onTap: () => onRowTap(product),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  ProductAvatar(product: product, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                product.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            if (variantCount > 1) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.2),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.style_outlined,
                                                      size: 10,
                                                      color: AppColors.primary,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      '$variantCount var.',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (activeIngredient != null &&
                                            activeIngredient.isNotEmpty)
                                          Text(
                                            '⚗️ $activeIngredient',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        else if (product.description != null &&
                                            product.description!.isNotEmpty)
                                          Text(
                                            product.description!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Categoría
                        DataCell(
                          Text(
                            product.categoryName ?? 'Sin categoría',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),

                        // Tipo
                        DataCell(ProductTypeBadge(type: product.productType)),

                        // Stock Total
                        DataCell(ProductStockBadge(stock: product.totalStock)),

                        // Estado
                        DataCell(
                          ProductStatusPill(
                            isActive: product.isActive,
                            onTap: () => onToggleActive(product),
                          ),
                        ),

                        // Acciones
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                hoverColor: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                tooltip: 'Ver Detalle y Variantes',
                                onPressed: () => onRowTap(product),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                hoverColor: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                tooltip: 'Editar Producto',
                                onPressed: () => onEdit(product),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                hoverColor: AppColors.error.withValues(
                                  alpha: 0.08,
                                ),
                                tooltip: 'Eliminar Producto',
                                onPressed: () => onDelete(product),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }
}
