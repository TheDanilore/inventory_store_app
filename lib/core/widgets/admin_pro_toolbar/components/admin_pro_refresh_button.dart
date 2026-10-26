import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Botón de refresco con rotación interactiva de 360° y animación continua durante carga.
/// Optimizado con [RepaintBoundary] para aislar repintados del árbol superior.
class AdminProRefreshButton extends StatefulWidget {
  final VoidCallback? onRefresh;
  final String tooltip;
  final bool isDesktop;
  final bool isLoading;

  const AdminProRefreshButton({
    super.key,
    this.onRefresh,
    required this.tooltip,
    this.isDesktop = false,
    this.isLoading = false,
  });

  @override
  State<AdminProRefreshButton> createState() => _AdminProRefreshButtonState();
}

class _AdminProRefreshButtonState extends State<AdminProRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isLoading) {
      _animCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AdminProRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _animCtrl.repeat();
      } else {
        _animCtrl.animateTo(1.0, curve: Curves.easeOutCubic).then((_) {
          if (mounted) _animCtrl.reset();
        });
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onRefresh == null) return;
    _animCtrl.forward(from: 0.0);
    AppFeedbackService.selectionClick();
    widget.onRefresh!();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTooltip =
        widget.tooltip.contains('Atajo')
            ? widget.tooltip
            : '${widget.tooltip} (Atajo: R o Alt+R)';

    // Aislamiento estricto de repintado en GPU mediante RepaintBoundary
    final iconWidget = RepaintBoundary(
      child: RotationTransition(
        turns: _animCtrl,
        child: const Icon(Icons.refresh_rounded, size: 20),
      ),
    );

    if (widget.isDesktop) {
      return Tooltip(
        message: effectiveTooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isDark
                        ? Colors.black.withValues(alpha: 0.15)
                        : const Color(0x050F172A),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onRefresh != null ? _handleTap : null,
              borderRadius: BorderRadius.circular(10),
              hoverColor:
                  isDark ? AppColors.darkSurfaceElevated : AppColors.background,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                  ),
                  child: iconWidget,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: effectiveTooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: IconButton(
        onPressed: widget.onRefresh != null ? _handleTap : null,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          hoverColor: AppColors.background,
          highlightColor: AppColors.teal.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: iconWidget,
      ),
    );
  }
}
