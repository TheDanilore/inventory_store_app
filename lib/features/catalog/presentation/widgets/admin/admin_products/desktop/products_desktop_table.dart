import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_avatar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_badges.dart';

/// Data-Grid Pro de escritorio de alta densidad para productos.
/// Construida sobre [AdminProTable] para una experiencia ejecutiva de nivel internacional.
class ProductsDesktopTable extends StatefulWidget {
  final List<ProductEntity> products;
  final Set<String> selectedProductIds;
  final Map<String, String> matchedIngredients;
  final void Function(String productId, bool selected) onProductSelected;
  final void Function(bool selectAll) onSelectAllPage;
  final void Function(ProductEntity product) onRowTap;
  final void Function(ProductEntity product) onToggleActive;
  final void Function(ProductEntity product) onEdit;
  final void Function(ProductEntity product) onDelete;

  /// Paginación integrada en el pie de la tabla (AdminProTable).
  final AdminTablePaginationConfig? paginationConfig;

  /// Muestra el skeleton de AdminProTable mientras carga el catálogo.
  final bool isLoading;

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
    this.paginationConfig,
    this.isLoading = false,
  });

  @override
  State<ProductsDesktopTable> createState() => _ProductsDesktopTableState();
}

class _ProductsDesktopTableState extends State<ProductsDesktopTable> {
  String? _sortColumnId;
  bool _isSortAscending = true;

  List<ProductEntity> _getSortedProducts() {
    if (_sortColumnId == null) return widget.products;
    final list = List<ProductEntity>.from(widget.products);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'product':
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'category':
          cmp = (a.categoryName ?? '').toLowerCase().compareTo(
            (b.categoryName ?? '').toLowerCase(),
          );
          break;
        case 'cost':
          cmp = (_costRange(a)?.min ?? 0.0).compareTo(
            _costRange(b)?.min ?? 0.0,
          );
          break;
        case 'price':
          final priceA = a.displaySalePrice ?? a.minSalePrice ?? 0.0;
          final priceB = b.displaySalePrice ?? b.minSalePrice ?? 0.0;
          cmp = priceA.compareTo(priceB);
          break;
        case 'stock':
          cmp = a.totalStock.compareTo(b.totalStock);
          break;
        case 'status':
          cmp = (a.isActive ? 1 : 0).compareTo(b.isActive ? 1 : 0);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
  }

  /// Costo de compra de referencia: (mín, máx) entre las variantes.
  /// Null si el producto no tiene variantes.
  ({double min, double max})? _costRange(ProductEntity p) {
    if (p.productVariants.isEmpty) return null;
    final costs = <double>[
      for (final v in p.productVariants) ((v.unitCost as num?) ?? 0).toDouble(),
    ];
    return (
      min: costs.reduce((a, b) => a < b ? a : b),
      max: costs.reduce((a, b) => a > b ? a : b),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedList = _getSortedProducts();

    return AdminProTable<ProductEntity>(
      items: sortedList,
      itemId: (p) => p.id,
      selectedIds: widget.selectedProductIds,
      onSelectionChanged: (ids) {
        // Notificar cambios de selección al controlador superior
        final newIds = ids.cast<String>();
        for (final p in widget.products) {
          final wasSelected = widget.selectedProductIds.contains(p.id);
          final isSelected = newIds.contains(p.id);
          if (wasSelected != isSelected) {
            widget.onProductSelected(p.id, isSelected);
          }
        }
      },
      sortColumnId: _sortColumnId,
      isSortAscending: _isSortAscending,
      onSort:
          (colId, asc) => setState(() {
            _sortColumnId = colId;
            _isSortAscending = asc;
          }),
      minTableWidth: 1080.0,
      margin: EdgeInsets.zero,
      paginationConfig: widget.paginationConfig,
      isLoading: widget.isLoading,
      onRowTap: widget.onRowTap,
      bulkActions: [
        AdminBulkAction<ProductEntity>(
          label: 'Copiar Nombres',
          icon: Icons.copy_rounded,
          onPressed: (selected) {
            final names = selected.map((p) => p.name).join('\n');
            _copyToClipboard(context, names, '${selected.length} productos');
          },
        ),
        AdminBulkAction<ProductEntity>(
          label: 'Activar',
          icon: Icons.play_circle_outline_rounded,
          onPressed: (selected) {
            for (final p in selected) {
              if (!p.isActive) widget.onToggleActive(p);
            }
          },
        ),
        AdminBulkAction<ProductEntity>(
          label: 'Desactivar',
          icon: Icons.pause_circle_outline_rounded,
          onPressed: (selected) {
            for (final p in selected) {
              if (p.isActive) widget.onToggleActive(p);
            }
          },
        ),
      ],
      columns: [
        // 1. Producto (Avatar + Nombre + Variantes + Principio activo)
        AdminTableColumn<ProductEntity>(
          id: 'product',
          label: 'PRODUCTO',
          flex: 4,
          isSortable: true,
          cellBuilder: (context, product) {
            final activeIngredient = widget.matchedIngredients[product.id];
            final variantCount = product.productVariants.length;

            return Row(
              children: [
                ProductAvatar(product: product, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (product.brandName != null &&
                              product.brandName!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                product.brandName!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                ),
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
            );
          },
        ),

        // 2. Categoría
        AdminTableColumn<ProductEntity>(
          id: 'category',
          label: 'CATEGORÍA',
          flex: 2,
          isSortable: true,
          cellBuilder:
              (context, product) => Text(
                product.categoryName ?? 'Sin categoría',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        ),

        // 3. Tipo
        AdminTableColumn<ProductEntity>(
          id: 'type',
          label: 'TIPO',
          fixedWidth: 110,
          cellBuilder:
              (context, product) => ProductTypeBadge(type: product.productType),
        ),

        // 4. Precio Compra (costo de referencia)
        AdminTableColumn<ProductEntity>(
          id: 'cost',
          label: 'P. COMPRA',
          fixedWidth: 120,
          isSortable: true,
          cellBuilder: (context, product) {
            final r = _costRange(product);
            if (r == null) {
              return const Text(
                '—',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              );
            }
            final multi = product.productVariants.length > 1;
            final value = r.min.toStringAsFixed(2);
            return Text(
              multi ? 'Desde S/ $value' : 'S/ $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                // Costo en 0 = dato pendiente de cargar → se resalta.
                color:
                    r.min <= 0
                        ? AppColors.warningDark
                        : AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
        ),

        // 5. Precio Venta
        AdminTableColumn<ProductEntity>(
          id: 'price',
          label: 'PRECIO VENTA',
          fixedWidth: 125,
          isSortable: true,
          cellBuilder: (context, product) {
            if (product.productVariants.length > 1 &&
                product.minSalePrice != null) {
              return Text(
                'Desde S/ ${product.minSalePrice!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            } else if (product.displaySalePrice != null) {
              return Text(
                'S/ ${product.displaySalePrice!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            }
            return const Text(
              '—',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            );
          },
        ),

        // 6. Stock Total
        AdminTableColumn<ProductEntity>(
          id: 'stock',
          label: 'STOCK TOTAL',
          fixedWidth: 130,
          isSortable: true,
          cellBuilder:
              (context, product) =>
                  ProductStockBadge(stock: product.totalStock),
        ),

        // 7. Estado
        AdminTableColumn<ProductEntity>(
          id: 'status',
          label: 'ESTADO',
          fixedWidth: 100,
          isSortable: true,
          cellBuilder:
              (context, product) => ProductStatusPill(
                isActive: product.isActive,
                onTap: () => widget.onToggleActive(product),
              ),
        ),

        // 8. Acciones
        AdminTableColumn<ProductEntity>(
          id: 'actions',
          label: 'ACCIONES',
          fixedWidth: 120,
          cellBuilder:
              (context, product) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    splashRadius: 16,
                    tooltip: 'Vista Rápida',
                    onPressed: () => widget.onRowTap(product),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    splashRadius: 16,
                    tooltip: 'Editar Producto',
                    onPressed: () => widget.onEdit(product),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: AppColors.slate,
                    ),
                    tooltip: 'Más acciones',
                    splashRadius: 16,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (val) {
                      if (val == 'toggle') {
                        widget.onToggleActive(product);
                      } else if (val == 'delete') {
                        widget.onDelete(product);
                      }
                    },
                    itemBuilder:
                        (ctx) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  product.isActive
                                      ? Icons.pause_circle_outline_rounded
                                      : Icons.play_circle_outline_rounded,
                                  size: 16,
                                  color:
                                      product.isActive
                                          ? AppColors.warningDark
                                          : AppColors.successDark,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  product.isActive
                                      ? 'Desactivar producto'
                                      : 'Activar producto',
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar producto',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
        ),
      ],
      // Mobile touch card
      mobileCardBuilder: (context, product, isSelected, onSelect) {
        return InkWell(
          onTap: () => widget.onRowTap(product),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ProductAvatar(product: product, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.categoryName ?? 'Sin categoría',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (product.displaySalePrice != null)
                            Text(
                              'S/ ${product.displaySalePrice!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          const Spacer(),
                          ProductStockBadge(stock: product.totalStock),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
