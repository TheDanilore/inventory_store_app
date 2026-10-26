import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';

/// Chip de filtro interactivo con micro-animaciones táctiles y selección visual.
class AdminFilterChip extends StatefulWidget {
  final AdminFilterOption<dynamic> option;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const AdminFilterChip({
    super.key,
    required this.option,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<AdminFilterChip> createState() => _AdminFilterChipState();
}

class _AdminFilterChipState extends State<AdminFilterChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.option.color ?? AppColors.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color:
                widget.selected
                    ? accent.withValues(alpha: widget.isDark ? 0.22 : 0.10)
                    : (widget.isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.background),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  widget.selected
                      ? accent
                      : (widget.isDark
                          ? AppColors.darkBorder
                          : AppColors.border),
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selected)
                Icon(Icons.check_rounded, size: 15, color: accent)
              else if (widget.option.icon != null)
                Icon(
                  widget.option.icon,
                  size: 15,
                  color: accent.withValues(alpha: 0.8),
                ),
              if (widget.selected || widget.option.icon != null)
                const SizedBox(width: 6),
              Text(
                widget.option.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w600,
                  color:
                      widget.selected
                          ? accent
                          : (widget.isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
