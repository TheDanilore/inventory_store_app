import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';

/// Selector desplegable estilizado para móvil cuando una lista de filtros
/// tiene muchas opciones (ej. Categorías con 10+ elementos) evitando un muro de chips.
class AdminFilterSelectField extends StatelessWidget {
  final AdminFilterGroup<dynamic> group;
  final bool isDark;

  const AdminFilterSelectField({
    super.key,
    required this.group,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final active = group.isActive;
    final accent = isDark ? const Color(0xFF60A5FA) : AppColors.primary;

    return PopupMenuButton<int>(
      tooltip: 'Seleccionar ${group.title}',
      offset: const Offset(0, 48),
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width - 40,
      ),
      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      onSelected: (i) {
        AppFeedbackService.selectionClick();
        group.select(group.options[i].value);
      },
      itemBuilder:
          (ctx) => [
            for (var i = 0; i < group.options.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(
                      group.isSelected(group.options[i].value)
                          ? Icons.check_circle_rounded
                          : (group.options[i].icon ?? Icons.circle_outlined),
                      size: 18,
                      color:
                          group.isSelected(group.options[i].value)
                              ? accent
                              : (group.options[i].color ??
                                  AppColors.textSecondary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.options[i].label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              group.isSelected(group.options[i].value)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                          color:
                              group.isSelected(group.options[i].value)
                                  ? (isDark
                                      ? Colors.white
                                      : AppColors.textPrimary)
                                  : (group.options[i].color ??
                                      (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color:
              active
                  ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
                  : (isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.background),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                active
                    ? accent
                    : (isDark ? AppColors.darkBorder : AppColors.border),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (group.icon != null) ...[
              Icon(
                group.icon,
                size: 18,
                color: active ? accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                group.selectedLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color:
                      active
                          ? (isDark ? accent : AppColors.primary)
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: active ? accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
