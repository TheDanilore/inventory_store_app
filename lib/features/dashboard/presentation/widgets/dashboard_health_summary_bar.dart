import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Barra animada que resume la salud operativa de inventario y lotes críticos.
class DashboardHealthSummaryBar extends StatefulWidget {
  final int lowStockCount;
  final int criticalBatchesCount;

  const DashboardHealthSummaryBar({
    super.key,
    required this.lowStockCount,
    required this.criticalBatchesCount,
  });

  @override
  State<DashboardHealthSummaryBar> createState() =>
      _DashboardHealthSummaryBarState();
}

class _DashboardHealthSummaryBarState extends State<DashboardHealthSummaryBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isButtonHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 3),
    ]).animate(_controller);

    if (widget.lowStockCount > 0 || widget.criticalBatchesCount > 0) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DashboardHealthSummaryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lowStockCount > 0 || widget.criticalBatchesCount > 0) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.lowStockCount == 0 && widget.criticalBatchesCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color:
              isDark
                  ? AppColors.darkSurface
                  : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark
                    ? const Color(0xFF059669).withValues(alpha: 0.35)
                    : AppColors.success.withValues(alpha: 0.25),
          ),
          boxShadow:
              isDark
                  ? []
                  : [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Inventario y Lotes Saludables · Cero Alertas Críticas',
              style: TextStyle(
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final totalAlerts = widget.lowStockCount + widget.criticalBatchesCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF78350F).withValues(alpha: 0.22)
                : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? const Color(0xFFB45309).withValues(alpha: 0.45)
                  : AppColors.warning.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFF59E0B,
            ).withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                        : AppColors.warning.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalAlerts Alertas de Salud Operativa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${widget.lowStockCount} stock bajo · ${widget.criticalBatchesCount} lotes en alerta',
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
          MouseRegion(
            onEnter: (_) => setState(() => _isButtonHovered = true),
            onExit: (_) => setState(() => _isButtonHovered = false),
            child: TextButton(
              onPressed: () {
                if (widget.criticalBatchesCount > 0) {
                  context.go('/inventory?tab=batches');
                } else {
                  context.go('/inventory');
                }
              },
              style: TextButton.styleFrom(
                foregroundColor:
                    isDark ? const Color(0xFFFBBF24) : AppColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(44, 38),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Revisar',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedSlide(
                    offset: Offset(_isButtonHovered ? 0.25 : 0.0, 0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.arrow_forward_rounded, size: 16),
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
