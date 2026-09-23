import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

class ProductDetailHeader extends StatelessWidget {
  final ProductEntity product;
  final bool isActive;
  final int effectiveStock;
  final String? sku;
  final VoidCallback onExportPdf;
  final bool isMobile;
  final bool showActions;
  final int variantCount;

  const ProductDetailHeader({
    super.key,
    required this.product,
    required this.isActive,
    required this.effectiveStock,
    this.sku,
    required this.onExportPdf,
    this.isMobile = false,
    this.showActions = false,
    this.variantCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return _buildMobileHeader(context);
    }
    return _buildDesktopHeader(context);
  }

  Widget _buildDesktopHeader(BuildContext context) {
    final statusColor =
        !isActive
            ? AppColors.textSecondary
            : effectiveStock > 0
            ? AppColors.success
            : AppColors.danger;

    final statusBg =
        !isActive
            ? AppColors.slateLight.withValues(alpha: 0.5)
            : effectiveStock > 0
            ? AppColors.successLight
            : AppColors.dangerLight;

    final statusText =
        !isActive
            ? 'Inactivo en Catálogo'
            : effectiveStock > 0
            ? 'En Stock ($effectiveStock unds)'
            : 'Agotado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Column: Identity, Status, Title, and Meta Chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Status Pill + Product Type Chip
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.slateLight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _humanizeProductType(product.productType),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 2: Big Product Name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),

                // Row 3: Meta Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (product.brandName != null &&
                        product.brandName!.isNotEmpty)
                      _buildMetaChip(
                        icon: Icons.verified_rounded,
                        imageUrl: product.brandLogoUrl,
                        label: 'Marca: ${product.brandName}',
                        color: AppColors.primary,
                        bgColor: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    if (variantCount > 0)
                      _buildMetaChip(
                        icon: Icons.layers_outlined,
                        label:
                            '$variantCount ${variantCount == 1 ? 'Variante' : 'Variantes'}',
                        color: AppColors.primaryDark,
                        bgColor: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    if (sku != null && sku!.isNotEmpty)
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: sku!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('SKU "$sku" copiado al portapapeles'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              width: 320,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Tooltip(
                          message: 'Clic para copiar SKU',
                          child: _buildMetaChip(
                            icon: Icons.qr_code_rounded,
                            label: 'SKU: $sku',
                          ),
                        ),
                      ),
                    if (product.usesBatches)
                      _buildMetaChip(
                        icon: Icons.calendar_month_rounded,
                        label: 'Control de Lotes',
                        color: AppColors.amberDark,
                        bgColor: AppColors.amberLight,
                      ),
                    if (product.stockControl)
                      _buildMetaChip(
                        icon: Icons.store_mall_directory_outlined,
                        label: 'Multi-Almacén Activo',
                        color: AppColors.tealDark,
                        bgColor: AppColors.tealLight,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Right Column: Summary Card or Action Buttons if showActions == true
          if (showActions) ...[
            const SizedBox(width: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: onExportPdf,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Exportar PDF',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildKbdBadge('Alt + P'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/products/product-form/${product.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Editar Producto',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildKbdBadge('Alt + E', isDark: true),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    !isActive
                        ? Icons.pause_circle_outline_rounded
                        : effectiveStock > 0
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        !isActive
                            ? 'Inactivo en Catálogo'
                            : effectiveStock > 0
                            ? 'Inventario Disponible'
                            : 'Sin Existencias',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        product.stockControl
                            ? '$effectiveStock unds en almacén'
                            : 'Stock no monitoreado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Exportar PDF',
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: onExportPdf,
              ),
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: () {
                  context.push('/products/product-form/${product.id}');
                },
              ),
            ],
          ),
          if (product.brandName != null && product.brandName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildMetaChip(
              icon: Icons.verified_rounded,
              imageUrl: product.brandLogoUrl,
              label: 'Marca: ${product.brandName}',
              color: AppColors.primary,
              bgColor: AppColors.primary.withValues(alpha: 0.08),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildMetaChip({
    required IconData icon,
    required String label,
    String? imageUrl,
    Color color = AppColors.textSecondary,
    Color bgColor = AppColors.background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.network(
                imageUrl,
                width: 14,
                height: 14,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(icon, size: 12, color: color),
              ),
            ),
          ] else ...[
            Icon(icon, size: 12, color: color),
          ],
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildKbdBadge(String text, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:
            isDark
                ? Colors.white.withValues(alpha: 0.18)
                : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppColors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static String _humanizeProductType(String type) {
    switch (type.toLowerCase().trim()) {
      case 'good':
        return 'Mercadería Física';
      case 'service':
        return 'Servicio';
      case 'raw_material':
        return 'Materia Prima';
      case 'finished_good':
        return 'Producto Terminado';
      case 'kit':
        return 'Kit / Combo';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }
}
