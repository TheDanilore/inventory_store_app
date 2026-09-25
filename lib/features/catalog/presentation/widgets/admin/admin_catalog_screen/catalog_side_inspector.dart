import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

/// Panel lateral de inspección rápida (Master-Detail) para Desktop/Tablet
/// y BottomSheet modal para Móvil.
class CatalogSideInspector extends StatelessWidget {
  final ProductEntity product;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onAddToCart;
  final Future<void> Function() onToggleActive;
  final bool isMobileSheet;

  const CatalogSideInspector({
    super.key,
    required this.product,
    required this.onClose,
    required this.onEdit,
    required this.onAddToCart,
    required this.onToggleActive,
    this.isMobileSheet = false,
  });

  /// Muestra el inspector como un BottomSheet en pantallas móviles.
  static Future<void> showAsBottomSheet(
    BuildContext context, {
    required ProductEntity product,
    required VoidCallback onEdit,
    required VoidCallback onAddToCart,
    required Future<void> Function() onToggleActive,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x2A000000),
                        blurRadius: 20,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: CatalogSideInspector(
                            product: product,
                            onClose: () => Navigator.of(ctx).pop(),
                            onEdit: () {
                              Navigator.of(ctx).pop();
                              onEdit();
                            },
                            onAddToCart: () {
                              Navigator.of(ctx).pop();
                              onAddToCart();
                            },
                            onToggleActive: onToggleActive,
                            isMobileSheet: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Color _stockStatusColor(int stock) {
    if (stock <= 5) return AppColors.danger;
    if (stock <= 15) return AppColors.warning;
    return AppColors.teal;
  }

  String _stockStatusLabel(int stock) {
    if (stock <= 0) return 'Agotado';
    if (stock <= 5) return 'Crítico ($stock)';
    if (stock <= 15) return 'Bajo ($stock)';
    return 'Disponible ($stock un.)';
  }

  @override
  Widget build(BuildContext context) {
    final defaultVariant = product.defaultVariant;
    final primaryImg = product.primaryImageUrl;
    final activeIng =
        product.details['active_ingredient']?.toString() ??
        product.details['ingrediente_activo']?.toString();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Cabecera del Inspector ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                product.isActive
                                    ? AppColors.successLight
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  product.isActive
                                      ? const Color(0xFFA7F3D0)
                                      : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      product.isActive
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                product.isActive ? 'ACTIVO' : 'INACTIVO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      product.isActive
                                          ? const Color(0xFF065F46)
                                          : AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (defaultVariant?.sku != null &&
                            defaultVariant!.sku!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            'SKU: ${defaultVariant.sku}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: 'Cerrar inspector (Esc)',
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // ── Cuerpo Desplazable ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image / Preview
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child:
                    primaryImg != null && primaryImg.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: primaryImg,
                          fit: BoxFit.contain,
                          placeholder:
                              (_, _) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          errorWidget: (_, _, _) => _buildPlaceholder(),
                        )
                        : _buildPlaceholder(),
              ),
              const SizedBox(height: 18),

              // Métricas Principales (Grid 2x2)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'PRECIO VENTA',
                      value:
                          'S/ ${(product.displaySalePrice ?? 0).toStringAsFixed(2)}',
                      icon: Icons.payments_outlined,
                      color: AppColors.tealDark,
                      badgeBg: AppColors.tealLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'STOCK TOTAL',
                      value: _stockStatusLabel(product.totalStock),
                      icon: Icons.inventory_2_outlined,
                      color: _stockStatusColor(product.totalStock),
                      badgeBg: _stockStatusColor(
                        product.totalStock,
                      ).withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'CATEGORÍA',
                      value: product.categoryName ?? 'Sin categoría',
                      icon: Icons.category_outlined,
                      color: AppColors.slate,
                      badgeBg: const Color(0xFFF1F5F9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'MARCA',
                      value: product.brandName ?? 'Sin marca',
                      icon: Icons.verified_outlined,
                      color: AppColors.slate,
                      badgeBg: const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),

              // Ingrediente Activo (si aplica)
              if (activeIng != null && activeIng.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.science_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ingrediente Activo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            Text(
                              activeIng,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Código de Barras (si tiene)
              if (defaultVariant?.barcode != null &&
                  defaultVariant!.barcode!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Código: ${defaultVariant.barcode}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Variantes (conteo rápido)
              if (product.productVariants.length > 1) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${product.productVariants.length} variantes configuradas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Barra Inferior de Acciones ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Botón primario: Editar
              ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text(
                  'Editar Producto Completo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botones secundarios en fila
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddToCart,
                      icon: const Icon(Icons.point_of_sale_rounded, size: 16),
                      label: const Text(
                        'Vender en POS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.tealDark,
                        side: const BorderSide(color: Color(0xFF99F6E4)),
                        backgroundColor: AppColors.tealLight.withValues(
                          alpha: 0.4,
                        ),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onToggleActive,
                      icon: Icon(
                        product.isActive
                            ? Icons.visibility_off_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                      ),
                      label: Text(
                        product.isActive ? 'Desactivar' : 'Activar',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            product.isActive
                                ? AppColors.textSecondary
                                : AppColors.success,
                        side: BorderSide(
                          color:
                              product.isActive
                                  ? AppColors.border
                                  : const Color(0xFFA7F3D0),
                        ),
                        backgroundColor:
                            product.isActive
                                ? AppColors.background
                                : AppColors.successLight.withValues(alpha: 0.3),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobileSheet) {
      return content;
    }

    // Estilo Master-Detail para Desktop (Ancho fijo de 380px con sombra sutil)
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          left: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SingleChildScrollView(child: content),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                product.name.trim().isNotEmpty
                    ? product.name.trim()[0].toUpperCase()
                    : 'P',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sin imagen disponible',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color badgeBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
