import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Pill / Chip de acción interactivo para celdas en tablas (`AdminProTable`).
///
/// Proporciona:
///  - Efecto Hover sombreado con micro-elevación y resplandor de acento.
///  - Cursor interactivo (`SystemMouseCursors.click`).
///  - Tooltip explicativo contextual.
///  - Soporte completo para Modo Claro y Modo Oscuro.
class AdminTableActionPill extends StatefulWidget {
  final String text;
  final String? prefix;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isMonospace;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const AdminTableActionPill({
    super.key,
    required this.text,
    this.prefix,
    this.icon,
    this.tooltip,
    this.onTap,
    this.accentColor,
    this.isMonospace = false,
    this.fontSize = 11.5,
    this.iconSize = 12.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
  });

  @override
  State<AdminTableActionPill> createState() => _AdminTableActionPillState();
}

class _AdminTableActionPillState extends State<AdminTableActionPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? AppColors.teal;
    final isInteractive = widget.onTap != null;

    final bgColor =
        _isHovered && isInteractive
            ? (isDark
                ? accent.withValues(alpha: 0.22)
                : accent.withValues(alpha: 0.12))
            : (isDark
                ? AppColors.darkSurfaceElevated
                : const Color(0xFFF1F5F9));

    final borderColor =
        _isHovered && isInteractive
            ? (isDark
                ? accent.withValues(alpha: 0.6)
                : accent.withValues(alpha: 0.45))
            : (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1));

    final textColor =
        _isHovered && isInteractive
            ? (isDark ? accent : AppColors.tealDark)
            : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);

    final iconColor =
        _isHovered && isInteractive
            ? (isDark ? accent : AppColors.tealDark)
            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary);

    final shadows =
        _isHovered && isInteractive
            ? [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.28 : 0.18),
                blurRadius: 6,
                offset: const Offset(0, 1.5),
              ),
            ]
            : const <BoxShadow>[];

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: _isHovered && isInteractive ? 1.2 : 0.9,
        ),
        boxShadow: shadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.prefix != null && widget.prefix!.isNotEmpty) ...[
            Text(
              widget.prefix!,
              style: TextStyle(
                fontSize: widget.fontSize * 0.9,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ],
          Flexible(
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontFamily: widget.isMonospace ? 'monospace' : null,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: widget.isMonospace ? 0.3 : 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.icon != null) ...[
            const SizedBox(width: 4),
            Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ],
        ],
      ),
    );

    if (isInteractive) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            AppFeedbackService.selectionClick();
            widget.onTap?.call();
          },
          child: content,
        ),
      );
    }

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      content = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 250),
        child: content,
      );
    }

    return content;
  }
}
