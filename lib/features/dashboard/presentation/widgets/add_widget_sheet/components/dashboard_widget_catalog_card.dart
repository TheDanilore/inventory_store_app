import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/add_widget_sheet/models/dashboard_widget_item.dart';

/// Tarjeta individual del catálogo de widgets del Dashboard.
/// Encapsula el estado de hover de manera atómica para evitar que el movimiento
/// del puntero reconstruya todo el panel ni las demás tarjetas.
class DashboardWidgetCatalogCard extends StatefulWidget {
  final DashboardWidgetItem item;
  final bool isVisible;
  final VoidCallback onToggle;

  const DashboardWidgetCatalogCard({
    super.key,
    required this.item,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  State<DashboardWidgetCatalogCard> createState() =>
      _DashboardWidgetCatalogCardState();
}

class _DashboardWidgetCatalogCardState
    extends State<DashboardWidgetCatalogCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final isVisible = widget.isVisible;

    return MouseRegion(
      onEnter: (_) {
        if (!_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform:
            _isHovered
                ? Matrix4.translationValues(0, -2.5, 0)
                : Matrix4.identity(),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                _isHovered
                    ? const Color(
                      0xFF3B82F6,
                    ).withValues(alpha: isDark ? 0.8 : 0.6)
                    : (isVisible
                        ? (isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                            : const Color(0xFF2563EB).withValues(alpha: 0.4))
                        : (isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE2E8F0))),
            width: _isHovered ? 1.6 : (isVisible ? 1.4 : 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  _isHovered
                      ? (isVisible
                          ? const Color(
                            0xFF3B82F6,
                          ).withValues(alpha: isDark ? 0.25 : 0.16)
                          : Colors.black.withValues(
                            alpha: isDark ? 0.45 : 0.08,
                          ))
                      : (isVisible
                          ? (isDark
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                              : const Color(0xFF2563EB).withValues(alpha: 0.05))
                          : (isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.02))),
              blurRadius: _isHovered ? 14 : 10,
              offset: _isHovered ? const Offset(0, 6) : const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Micro-mockup Vectorial
            item.previewMockup,
            const SizedBox(width: 14),

            // Center: Title, Description & Category Pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 11.5,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          item.categoryTag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Action Button (+ Añadir o ✓ Activo o Próximamente)
            Align(
              alignment: Alignment.center,
              child:
                  item.isComingSoon
                      ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color:
                                  isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Próximamente',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                      : InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.onToggle,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isVisible
                                    ? (isDark
                                        ? const Color(
                                          0xFF1E3A8A,
                                        ).withValues(alpha: 0.45)
                                        : const Color(0xFFEFF6FF))
                                    : const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                isVisible
                                    ? Border.all(
                                      color:
                                          isDark
                                              ? const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.6)
                                              : const Color(0xFFBFDBFE),
                                    )
                                    : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVisible
                                    ? Icons.check_circle_rounded
                                    : Icons.add_rounded,
                                size: 14,
                                color:
                                    isVisible
                                        ? (isDark
                                            ? const Color(0xFF60A5FA)
                                            : const Color(0xFF2563EB))
                                        : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVisible ? 'Activo' : 'Añadir',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isVisible
                                          ? (isDark
                                              ? const Color(0xFF60A5FA)
                                              : const Color(0xFF2563EB))
                                          : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
