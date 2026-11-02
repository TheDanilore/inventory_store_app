import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';

class AdminProViewToggle extends StatelessWidget {
  final AdminProViewToggleConfig config;

  const AdminProViewToggle({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        config.activeColor ??
        (isDark ? const Color(0xFF60A5FA) : AppColors.tealDark);

    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
          ),
        ),
        child: SizedBox(
          width: 76,
          child: Stack(
            children: [
              AnimatedAlign(
                alignment:
                    config.isTableView
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 35,
                  height: 34,
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.08,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Tooltip(
                      message: '${config.tableTooltip} (Atajo: V)',
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () {
                          AppFeedbackService.selectionClick();
                          config.onToggleTableView(true);
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Center(
                          child: Icon(
                            config.tableIcon,
                            size: 18,
                            color:
                                config.isTableView
                                    ? activeColor
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Tooltip(
                      message: '${config.cardsTooltip} (Atajo: V)',
                      waitDuration: const Duration(milliseconds: 300),
                      child: InkWell(
                        onTap: () {
                          AppFeedbackService.selectionClick();
                          config.onToggleTableView(false);
                        },
                        borderRadius: BorderRadius.circular(7),
                        child: Center(
                          child: Icon(
                            config.cardsIcon,
                            size: 18,
                            color:
                                !config.isTableView
                                    ? activeColor
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
