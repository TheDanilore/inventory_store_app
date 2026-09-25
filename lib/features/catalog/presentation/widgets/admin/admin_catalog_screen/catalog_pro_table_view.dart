import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

/// Tabla de datos de alta densidad ("Pro Data Table") para Desktop y Tablet.
/// Diseñada con estética inspirada en Stripe y Linear para administradores "Power Users".
class CatalogProTableView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final effectiveTotal = totalCount ?? products.length;
    final totalPages =
        effectiveTotal == 0 ? 1 : (effectiveTotal / pageSize).ceil();
    final start = effectiveTotal == 0 ? 0 : (currentPage * pageSize) + 1;
    final end = ((currentPage + 1) * pageSize) > effectiveTotal
        ? effectiveTotal
        : (currentPage + 1) * pageSize;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (headerSliver != null) headerSliver!,
        if (chipsSliver != null) chipsSliver!,

        // ── Barra de Conteo y Resumen ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Text(
                  'Mostrando $start-$end de $effectiveTotal productos',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Vista Tabla Pro',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Pág. ${currentPage + 1} de $totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Contenedor de la Tabla ──────────────────────────────────────────
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 16),
          sliver: SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow(opacity: 0.03),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Cabecera Fija de la Tabla
                  _buildTableHeader(),
                  const Divider(height: 1, color: AppColors.border),

                  // Filas de Productos
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final isSelected = selectedProduct?.id == product.id;
                      return _ProductTableRow(
                        product: product,
                        isSelected: isSelected,
                        onTap: () => onProductSelected(product),
                        onEdit: () => onEdit(product),
                        onToggleActive: () => onToggleActive(product),
                        onSale: () => onSale(product),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          // Producto (Miniatura + Nombre + Marca)
          Expanded(
            flex: 6,
            child: Text(
              'PRODUCTO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // Categoría
          Expanded(
            flex: 3,
            child: Text(
              'CATEGORÍA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // Stock
          Expanded(
            flex: 3,
            child: Text(
              'STOCK DISPONIBLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // Precio
          Expanded(
            flex: 3,
            child: Text(
              'PRECIO VENTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // Estado
          Expanded(
            flex: 2,
            child: Text(
              'ESTADO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),

          // Acciones
          SizedBox(
            width: 140,
            child: Text(
              'ACCIONES',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTableRow extends StatefulWidget {
  final ProductEntity product;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onToggleActive;
  final VoidCallback onSale;

  const _ProductTableRow({
    required this.product,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onToggleActive,
    required this.onSale,
  });

  @override
  State<_ProductTableRow> createState() => _ProductTableRowState();
}

class _ProductTableRowState extends State<_ProductTableRow> {
  bool _isHovered = false;
  bool _isToggling = false;

  Color _stockColor(int stock) {
    if (stock <= 5) return AppColors.danger;
    if (stock <= 15) return AppColors.warning;
    return AppColors.tealDark;
  }

  Color _stockBg(int stock) {
    if (stock <= 5) return const Color(0xFFFEE2E2);
    if (stock <= 15) return const Color(0xFFFEF3C7);
    return const Color(0xFFCCFBF1);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final defaultVariant = product.defaultVariant;
    final primaryImg = product.primaryImageUrl;

    Color rowBackground = Colors.white;
    if (widget.isSelected) {
      rowBackground = const Color(0xFFEFF6FF); // Slate Blue highlight
    } else if (_isHovered) {
      rowBackground = const Color(0xFFF8FAFC);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: rowBackground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // ── 1. PRODUCTO (Miniatura + Nombre + Marca + SKU) ────────────
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    // Miniatura con radio sutil
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: primaryImg != null && primaryImg.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: primaryImg,
                              fit: BoxFit.cover,
                              memCacheWidth: 100,
                              memCacheHeight: 100,
                              errorWidget: (_, _, _) =>
                                  _buildInitialThumbnail(product.name),
                            )
                          : _buildInitialThumbnail(product.name),
                    ),
                    const SizedBox(width: 12),

                    // Textos
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: product.isActive
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                                    decoration: !product.isActive
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isSelected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Viendo',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (product.brandName != null &&
                                  product.brandName!.isNotEmpty) ...[
                                Text(
                                  product.brandName!.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  '•',
                                  style: TextStyle(
                                    color: AppColors.border,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                defaultVariant?.sku != null &&
                                        defaultVariant!.sku!.isNotEmpty
                                    ? 'SKU: ${defaultVariant.sku}'
                                    : 'ID: ${product.id.length > 8 ? product.id.substring(0, 8) : product.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 2. CATEGORÍA ──────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      product.categoryName ?? 'Sin categoría',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // ── 3. STOCK DISPONIBLE ───────────────────────────────────────
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _stockBg(product.totalStock),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _stockColor(product.totalStock),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            product.totalStock <= 0
                                ? '0 un. (Agotado)'
                                : '${product.totalStock} un.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _stockColor(product.totalStock),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 4. PRECIO DE VENTA ────────────────────────────────────────
              Expanded(
                flex: 3,
                child: Text(
                  'S/ ${(product.displaySalePrice ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: product.isActive
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),

              // ── 5. ESTADO (Activo / Inactivo con Toggle) ──────────────────
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _isToggling
                      ? null
                      : () async {
                          setState(() => _isToggling = true);
                          try {
                            await widget.onToggleActive();
                          } finally {
                            if (mounted) setState(() => _isToggling = false);
                          }
                        },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isToggling)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            product.isActive
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_off_rounded,
                            size: 16,
                            color: product.isActive
                                ? AppColors.success
                                : AppColors.textMuted,
                          ),
                        const SizedBox(width: 5),
                        Text(
                          product.isActive ? 'Activo' : 'Pausado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: product.isActive
                                ? AppColors.successDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 6. ACCIONES RÁPIDAS ────────────────────────────────────────
              SizedBox(
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Inspeccionar
                    Tooltip(
                      message: 'Ver detalles rápidos',
                      child: IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        onPressed: widget.onTap,
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          hoverColor: AppColors.background,
                        ),
                      ),
                    ),

                    // Editar
                    Tooltip(
                      message: 'Editar producto',
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: widget.onEdit,
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          hoverColor: AppColors.primaryLight,
                        ),
                      ),
                    ),

                    // POS
                    Tooltip(
                      message: 'Agregar a POS',
                      child: IconButton(
                        icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                        onPressed: widget.onSale,
                        style: IconButton.styleFrom(
                          foregroundColor: AppColors.tealDark,
                          hoverColor: AppColors.tealLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialThumbnail(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'P';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Shimmer para la tabla de productos durante estado de carga.
class CatalogTableSkeleton extends StatelessWidget {
  const CatalogTableSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Expanded(
                  flex: 6,
                  child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 3,
                  child: AppShimmer(width: 60, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 3,
                  child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 3,
                  child: AppShimmer(width: 60, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 50, height: 12, borderRadius: 4),
                ),
                SizedBox(
                  width: 140,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const AppShimmer(width: 44, height: 44, borderRadius: 10),
                  const SizedBox(width: 12),
                  const Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmer(
                          width: double.infinity,
                          height: 14,
                          borderRadius: 4,
                        ),
                        SizedBox(height: 6),
                        AppShimmer(width: 100, height: 10, borderRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    flex: 3,
                    child: AppShimmer(width: 70, height: 20, borderRadius: 6),
                  ),
                  const Expanded(
                    flex: 3,
                    child: AppShimmer(width: 60, height: 20, borderRadius: 6),
                  ),
                  const Expanded(
                    flex: 3,
                    child: AppShimmer(width: 60, height: 16, borderRadius: 4),
                  ),
                  const Expanded(
                    flex: 2,
                    child: AppShimmer(width: 50, height: 16, borderRadius: 4),
                  ),
                  const SizedBox(
                    width: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppShimmer(width: 28, height: 28, borderRadius: 6),
                        SizedBox(width: 6),
                        AppShimmer(width: 28, height: 28, borderRadius: 6),
                        SizedBox(width: 6),
                        AppShimmer(width: 28, height: 28, borderRadius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
