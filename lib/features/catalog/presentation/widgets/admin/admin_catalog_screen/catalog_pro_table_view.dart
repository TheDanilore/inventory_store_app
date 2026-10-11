import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_avatar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_badges.dart';

/// Tabla de datos de alta densidad ("Pro Data Table") para Desktop y Tablet.
/// Diseñada con estética ejecutiva utilizando [AdminProTable].
class CatalogProTableView extends StatefulWidget {
  final List<ProductEntity> products;
  final int pageSize;
  final int currentPage;
  final int? totalCount;
  final ValueChanged<int> onPageChanged;
  final void Function(ProductEntity) onSale;
  final Future<void> Function(ProductEntity) onToggleActive;
  final void Function(ProductEntity) onEdit;
  final void Function(ProductEntity) onProductSelected;
  final ProductEntity? selectedProduct;
  final Widget? headerSliver;
  final Widget? chipsSliver;
  final double bottomPadding;

  const CatalogProTableView({
    super.key,
    required this.products,
    required this.pageSize,
    required this.currentPage,
    this.totalCount,
    required this.onPageChanged,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    required this.onProductSelected,
    this.selectedProduct,
    this.headerSliver,
    this.chipsSliver,
    this.bottomPadding = 0,
  });

  @override
  State<CatalogProTableView> createState() => _CatalogProTableViewState();
}

class _CatalogProTableViewState extends State<CatalogProTableView> {
  final Set<Object> _selectedIds = {};
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
          cmp = (a.categoryName ?? '').toLowerCase().compareTo((b.categoryName ?? '').toLowerCase());
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

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = widget.totalCount ?? widget.products.length;
    final sortedProducts = _getSortedProducts();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (widget.headerSliver != null) widget.headerSliver!,
        if (widget.chipsSliver != null) widget.chipsSliver!,

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AdminProTable<ProductEntity>(
              items: sortedProducts,
              itemId: (p) => p.id,
              selectedIds: _selectedIds,
              onSelectionChanged: (ids) => setState(() => _selectedIds
                ..clear()
                ..addAll(ids)),
              sortColumnId: _sortColumnId,
              isSortAscending: _isSortAscending,
              onSort: (colId, asc) => setState(() {
                _sortColumnId = colId;
                _isSortAscending = asc;
              }),
              minTableWidth: 920.0,
              margin: EdgeInsets.zero,
              onRowTap: widget.onProductSelected,
              paginationConfig: AdminTablePaginationConfig(
                currentPage: widget.currentPage + 1,
                pageSize: widget.pageSize,
                totalItems: effectiveTotal,
                onPageChanged: (p) => widget.onPageChanged(p - 1),
                onPageSizeChanged: (_) {},
              ),
              bulkActions: [
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
                // 1. Producto (Avatar + Nombre + Marca)
                AdminTableColumn<ProductEntity>(
                  id: 'product',
                  label: 'PRODUCTO',
                  flex: 4,
                  isSortable: true,
                  cellBuilder: (context, product) {
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
                              Text(
                                product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  if (variantCount > 1) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$variantCount var.',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (product.brandName != null &&
                                      product.brandName!.isNotEmpty)
                                    Text(
                                      product.brandName!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                ],
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
                  cellBuilder: (context, product) => Text(
                    product.categoryName ?? 'Sin categoría',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                // 3. Stock
                AdminTableColumn<ProductEntity>(
                  id: 'stock',
                  label: 'STOCK DISPONIBLE',
                  fixedWidth: 140,
                  isSortable: true,
                  cellBuilder: (context, product) => ProductStockBadge(stock: product.totalStock),
                ),

                // 4. Precio Venta
                AdminTableColumn<ProductEntity>(
                  id: 'price',
                  label: 'PRECIO VENTA',
                  fixedWidth: 135,
                  isSortable: true,
                  cellBuilder: (context, product) {
                    if (product.displaySalePrice != null) {
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
                    return const Text('—', style: TextStyle(color: AppColors.textMuted));
                  },
                ),

                // 5. Estado
                AdminTableColumn<ProductEntity>(
                  id: 'status',
                  label: 'ESTADO',
                  fixedWidth: 110,
                  isSortable: true,
                  cellBuilder: (context, product) => ProductStatusPill(
                    isActive: product.isActive,
                    onTap: () => widget.onToggleActive(product),
                  ),
                ),

                // 6. Acciones
                AdminTableColumn<ProductEntity>(
                  id: 'actions',
                  label: 'ACCIONES',
                  fixedWidth: 110,
                  cellBuilder: (context, product) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                        tooltip: 'Vender',
                        splashRadius: 14,
                        color: AppColors.teal,
                        onPressed: () => widget.onSale(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Editar',
                        splashRadius: 14,
                        color: AppColors.textSecondary,
                        onPressed: () => widget.onEdit(product),
                      ),
                    ],
                  ),
                ),
              ],
              mobileCardBuilder: (context, product, isSelected, onSelect) {
                return InkWell(
                  onTap: () => widget.onProductSelected(product),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ProductAvatar(product: product, size: 38),
                        const SizedBox(width: 10),
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
                            ],
                          ),
                        ),
                        ProductStockBadge(stock: product.totalStock),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: widget.bottomPadding + 16)),
      ],
    );
  }
}

class CatalogTableSkeleton extends StatelessWidget {
  const CatalogTableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppTableShimmer(rowCount: 8, minWidth: 920.0);
  }
}

