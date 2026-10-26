import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_image_placeholder.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Tarjeta que lista los lotes próximos a vencer o vencidos con criterio FEFO.
class ExpiringBatchesCard extends StatefulWidget {
  final List<Map<String, dynamic>> batches;
  final VoidCallback? onHide;

  const ExpiringBatchesCard({super.key, required this.batches, this.onHide});

  @override
  State<ExpiringBatchesCard> createState() => _ExpiringBatchesCardState();
}

class _ExpiringBatchesCardState extends State<ExpiringBatchesCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final batches = widget.batches;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (batches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(
              0xFF10B981,
            ).withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1.2,
          ),
          boxShadow: isDark ? [] : AppColors.cardShadow(opacity: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lotes Críticos por Vencer (FEFO)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark
                                  ? const Color(0xFFF8FAFC)
                                  : AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Control preventivo de caducidad en almacén',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✓ 100% Vigente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.25)
                        : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF059669).withValues(alpha: 0.35)
                          : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF16A34A),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Salud Fitosanitaria Óptima',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No hay lotes vencidos ni que expiren en los próximos 30 días. Tu stock de semillas, fertilizantes y agroquímicos está vigente.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color:
                                isDark
                                    ? const Color(0xFF6EE7B7)
                                    : const Color(
                                      0xFF166534,
                                    ).withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.go('/inventory?tab=batches'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gestionar lotes y almacenes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final urgent = batches.take(3).toList();
    final expiredCount =
        batches.where((b) {
          final expiryStr = b['expiry_date'] as String?;
          final expiryDate =
              expiryStr != null ? DateTime.tryParse(expiryStr) : null;
          return expiryDate != null && expiryDate.isBefore(DateTime.now());
        }).length;
    final expiringSoonCount = batches.length - expiredCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: isDark ? [] : AppColors.cardShadow(opacity: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.timelapse_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lotes Críticos por Vencer (FEFO)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      expiredCount > 0
                          ? '$expiredCount vencido(s) · $expiringSoonCount por vencer'
                          : '${batches.length} lote(s) requieren rotación prioritaria en POS',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (expiredCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⚠️ $expiredCount Vencido(s)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          MouseRegion(
            onExit: (_) {
              if (_hoveredIndex != null) {
                setState(() => _hoveredIndex = null);
              }
            },
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urgent.length,
              separatorBuilder:
                  (context, index) => Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
              itemBuilder: (context, index) {
                final b = urgent[index];
                final isHovered = _hoveredIndex == index;

                // Mapeo defensivo de campos (PostgreSQL vs Dart)
                final expiryStr = b['expiry_date'] as String?;
                final expiryDate =
                    expiryStr != null ? DateTime.tryParse(expiryStr) : null;
                final days =
                    expiryDate != null
                        ? expiryDate.difference(DateTime.now()).inDays
                        : (b['days_until_expiration'] as int? ?? 0);

                final code =
                    (b['batch_number'] ?? b['batch_code'] ?? 'S/L').toString();
                final prod =
                    (b['products'] is Map
                            ? b['products']['name']
                            : (b['product_name'] ?? 'Insumo'))
                        .toString();

                String? imgUrl;
                if (b['products'] is Map) {
                  final prodImgs =
                      b['products']['product_images'] as List<dynamic>?;
                  if (prodImgs != null && prodImgs.isNotEmpty) {
                    final mainImg =
                        prodImgs.firstWhere(
                              (img) =>
                                  (img as Map<String, dynamic>)['is_main'] ==
                                  true,
                              orElse: () => prodImgs.first,
                            )
                            as Map<String, dynamic>?;
                    imgUrl = mainImg?['image_url'] as String?;
                  }
                }
                if (imgUrl == null && b['product_variants'] is Map) {
                  final varImgs =
                      b['product_variants']['product_images'] as List<dynamic>?;
                  if (varImgs != null && varImgs.isNotEmpty) {
                    final mainImg =
                        varImgs.firstWhere(
                              (img) =>
                                  (img as Map<String, dynamic>)['is_main'] ==
                                  true,
                              orElse: () => varImgs.first,
                            )
                            as Map<String, dynamic>?;
                    imgUrl = mainImg?['image_url'] as String?;
                  }
                }

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) {
                    if (_hoveredIndex != index) {
                      setState(() => _hoveredIndex = index);
                    }
                  },
                  child: GestureDetector(
                    onTap: () {
                      context.go('/inventory?tab=batches');
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            isHovered
                                ? (isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.primaryLight.withValues(
                                      alpha: 0.45,
                                    ))
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          ProductThumbnail(
                            imageUrl: imgUrl,
                            productName: prod,
                            width: 34,
                            height: 34,
                            compact: true,
                            isDark: isDark,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark
                                            ? const Color(0xFFF8FAFC)
                                            : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Lote: $code · Click para revisar stock',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        isDark
                                            ? const Color(0xFF94A3B8)
                                            : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              Widget chip = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      days <= 0
                                          ? AppColors.error.withValues(
                                            alpha: 0.16,
                                          )
                                          : days <= 7
                                          ? AppColors.error.withValues(
                                            alpha: 0.12,
                                          )
                                          : AppColors.warning.withValues(
                                            alpha: 0.12,
                                          ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color:
                                        days <= 0
                                            ? AppColors.error.withValues(
                                              alpha: 0.35,
                                            )
                                            : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  days < 0
                                      ? 'Vencido (${days.abs()}d)'
                                      : days == 0
                                      ? 'Vence hoy'
                                      : days == 1
                                      ? '1 día'
                                      : '$days días',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        days <= 7
                                            ? AppColors.error
                                            : AppColors.warning,
                                  ),
                                ),
                              );

                              if (days <= 0) {
                                chip = chip
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .boxShadow(
                                      begin: BoxShadow(
                                        color: AppColors.error.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 2,
                                      ),
                                      end: BoxShadow(
                                        color: AppColors.error.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 900,
                                      ),
                                    );
                              }

                              return chip;
                            },
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => context.go('/inventory?tab=batches'),
              style: TextButton.styleFrom(
                backgroundColor:
                    isDark
                        ? AppColors.darkSurfaceElevated
                        : const Color(0xFFEFF6FF),
                foregroundColor:
                    isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color:
                        isDark ? AppColors.darkBorder : const Color(0xFFBFDBFE),
                  ),
                ),
              ),
              icon: Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
              ),
              label: Text(
                'Gestionar todos los lotes (${batches.length})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
