import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';

/// Tabla pro de productos con mayor rotación (Best Sellers).
class DashboardBestSellersTable extends StatefulWidget {
  final List<Map<String, dynamic>>? bestSellers;
  final List<Map<String, dynamic>> criticalBatches;
  final VoidCallback? onHide;

  const DashboardBestSellersTable({
    super.key,
    this.bestSellers,
    required this.criticalBatches,
    this.onHide,
  });

  @override
  State<DashboardBestSellersTable> createState() =>
      _DashboardBestSellersTableState();
}

class _DashboardBestSellersTableState extends State<DashboardBestSellersTable> {
  int? _hoveredRank;

  Widget _buildProductThumbnail({
    required String? imageUrl,
    double size = 32,
    bool isDark = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          imageUrl != null && imageUrl.trim().isNotEmpty
              ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: size * 0.45,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: size * 0.45,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
              )
              : Container(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                alignment: Alignment.center,
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: size * 0.45,
                  color: const Color(0xFF94A3B8),
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final products =
        (widget.bestSellers != null && widget.bestSellers!.isNotEmpty)
            ? widget.bestSellers!
            : <Map<String, dynamic>>[];

    final canNavigateToInventoryOrProduct = context.hasAnyPermission(const [
      AppPermissions.productsView,
      AppPermissions.inventoryView,
    ]);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow:
                isDark
                    ? []
                    : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Productos con Mayor Rotación',
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Artículos más despachados y rendimiento financiero',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (products.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 16,
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFF94A3B8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin ventas en este período',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registra ventas en el POS para ver la rotación de artículos en tiempo real.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => context.go('/pos'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1,
                        ),
                        icon: const Icon(Icons.point_of_sale_rounded, size: 15),
                        label: const Text(
                          'Registrar Venta en POS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isMobile)
                // ── VISTA MÓVIL: CARDS TIPO LISTA ─────────────────────────
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  separatorBuilder:
                      (context, index) => Divider(
                        height: 1,
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFF1F5F9),
                      ),
                  itemBuilder: (context, index) {
                    final p = products[index];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        hoverColor:
                            isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.primaryLight.withValues(
                                  alpha: 0.45,
                                ),
                        onTap:
                            canNavigateToInventoryOrProduct
                                ? () {
                                  final prodId = p['productId'] as String?;
                                  if (prodId != null && prodId.isNotEmpty) {
                                    context.go('/product/$prodId');
                                  } else {
                                    context.go('/inventory');
                                  }
                                }
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              _buildProductThumbnail(
                                imageUrl: p['imageUrl'] as String?,
                                size: 38,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['name'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            isDark
                                                ? const Color(0xFFF8FAFC)
                                                : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          p['category'] as String,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '•',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                isDark
                                                    ? const Color(0xFF64748B)
                                                    : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          p['sold'] as String,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isDark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p['revenue'] as String,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ((p['statusColor'] is Color
                                              ? p['statusColor'] as Color
                                              : (p['status'] == 'Alta Rotación'
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF2563EB))))
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      p['status'] as String,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            (p['statusColor'] is Color
                                                ? p['statusColor'] as Color
                                                : (p['status'] ==
                                                        'Alta Rotación'
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFF2563EB))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (canNavigateToInventoryOrProduct) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color:
                                      isDark
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF94A3B8),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              else
                // ── VISTA DESKTOP / TABLET: DATA TABLE PRO ────────────────
                MouseRegion(
                  onExit: (_) {
                    if (_hoveredRank != null) {
                      setState(() => _hoveredRank = null);
                    }
                  },
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                '#',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                'CÓDIGO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: Text(
                                'PRODUCTO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'CATEGORÍA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'DESPACHO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'FACTURACIÓN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                'ESTADO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Table Rows
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder:
                            (context, index) => Divider(
                              height: 1,
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFF1F5F9),
                            ),
                        itemBuilder: (context, index) {
                          final p = products[index];
                          final rank = index + 1;
                          final isHovered = _hoveredRank == rank;

                          return MouseRegion(
                            cursor:
                                canNavigateToInventoryOrProduct
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                            onEnter: (_) {
                              if (_hoveredRank != rank) {
                                setState(() => _hoveredRank = rank);
                              }
                            },
                            child: GestureDetector(
                              onTap:
                                  canNavigateToInventoryOrProduct
                                      ? () {
                                        final prodId =
                                            p['productId'] as String?;
                                        if (prodId != null &&
                                            prodId.isNotEmpty) {
                                          context.go('/product/$prodId');
                                        } else {
                                          context.go('/inventory');
                                        }
                                      }
                                      : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      isHovered
                                          ? (isDark
                                              ? AppColors.darkSurfaceElevated
                                              : AppColors.primaryLight
                                                  .withValues(alpha: 0.45))
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    // Rank
                                    SizedBox(
                                      width: 44,
                                      child: Row(
                                        children: [
                                          if (rank <= 3) ...[
                                            Icon(
                                              Icons.workspace_premium_rounded,
                                              size: 16,
                                              color:
                                                  rank == 1
                                                      ? const Color(0xFFF59E0B)
                                                      : rank == 2
                                                      ? const Color(0xFF64748B)
                                                      : const Color(0xFFB45309),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            '$rank',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color:
                                                  rank == 1
                                                      ? const Color(0xFFF59E0B)
                                                      : rank == 2
                                                      ? const Color(0xFF64748B)
                                                      : rank == 3
                                                      ? const Color(0xFFB45309)
                                                      : (isDark
                                                          ? const Color(
                                                            0xFF94A3B8,
                                                          )
                                                          : const Color(
                                                            0xFF64748B,
                                                          )),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Código
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        p['id'] as String,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Thumbnail + Nombre del Producto
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        children: [
                                          _buildProductThumbnail(
                                            imageUrl: p['imageUrl'] as String?,
                                            size: 30,
                                            isDark: isDark,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              p['name'] as String,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFFF8FAFC,
                                                        )
                                                        : const Color(
                                                          0xFF0F172A,
                                                        ),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Categoría
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        p['category'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // Despachados
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['sold'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),

                                    // Facturación
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        p['revenue'] as String,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),

                                    // Estado
                                    SizedBox(
                                      width: 100,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ((p['statusColor'] is Color
                                                  ? p['statusColor'] as Color
                                                  : (p['status'] ==
                                                          'Alta Rotación'
                                                      ? const Color(0xFF16A34A)
                                                      : const Color(
                                                        0xFF2563EB,
                                                      ))))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          p['status'] as String,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                (p['statusColor'] is Color
                                                    ? p['statusColor'] as Color
                                                    : (p['status'] ==
                                                            'Alta Rotación'
                                                        ? const Color(
                                                          0xFF16A34A,
                                                        )
                                                        : const Color(
                                                          0xFF2563EB,
                                                        ))),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),
                                    if (canNavigateToInventoryOrProduct)
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color:
                                            isDark
                                                ? const Color(0xFF64748B)
                                                : const Color(0xFF94A3B8),
                                      )
                                    else
                                      const SizedBox(width: 16),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
