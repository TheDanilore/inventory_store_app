import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';

/// Dropdown de desktop/tablet generado desde un [AdminFilterGroup].
class AdminFilterDropdown extends StatelessWidget {
  final AdminFilterGroup<dynamic> group;

  const AdminFilterDropdown({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = group.isActive;
    final accent = isDark ? const Color(0xFF2DD4BF) : AppColors.teal;

    return PopupMenuButton<int>(
      tooltip: group.title,
      offset: const Offset(0, 44),
      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      onSelected: (i) => group.select(group.options[i].value),
      itemBuilder:
          (_) => [
            for (var i = 0; i < group.options.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(
                      group.options[i].icon ??
                          (group.options[i].value == group.selected
                              ? Icons.check_rounded
                              : Icons.circle_outlined),
                      size: 16,
                      color: group.options[i].color ?? AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      group.options[i].label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            group.options[i].value == group.selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                        color: group.options[i].color,
                      ),
                    ),
                  ],
                ),
              ),
          ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              active
                  ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
                  : (isDark ? AppColors.darkSurfaceElevated : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                active
                    ? accent
                    : (isDark
                        ? AppColors.darkBorderSubtle
                        : const Color(0xFFCBD5E1)),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              group.icon ?? Icons.filter_list_rounded,
              size: 15,
              color: active ? accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              active ? group.selectedLabel : group.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color:
                    active
                        ? (isDark ? accent : AppColors.tealDark)
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? accent : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
