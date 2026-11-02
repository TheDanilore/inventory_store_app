import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_pro_refresh_button.dart';

class AdminMobileFiltersTriggerButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onOpenFilters;

  const AdminMobileFiltersTriggerButton({
    super.key,
    required this.activeCount,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActive = activeCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color:
                hasActive
                    ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.08)
                    : (isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.surface),
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(
              color:
                  hasActive
                      ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                      : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              AppFeedbackService.lightImpact();
              onOpenFilters();
            },
            icon: Icon(
              Icons.tune_rounded,
              size: 20,
              color: hasActive ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: 'Filtros (Atajo: F)',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(10),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder:
                (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                  child: c,
                ),
            child:
                hasActive
                    ? Container(
                      key: ValueKey(activeCount),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                    : const SizedBox.shrink(key: ValueKey(0)),
          ),
        ),
      ],
    );
  }
}

class AdminMobileTrailingActionsButton extends StatelessWidget {
  final String title;
  final List<Widget> trailingActions;

  const AdminMobileTrailingActionsButton({
    super.key,
    required this.title,
    required this.trailingActions,
  });

  void _showModal(BuildContext context) {
    if (trailingActions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.more_horiz_rounded,
                            size: 22,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.textMuted,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.divider, height: 20),
                  for (final action in trailingActions) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: action,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 300),
        child: IconButton(
          onPressed: () => _showModal(context),
          icon: Icon(
            Icons.more_vert_rounded,
            size: 20,
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.all(10),
        ),
      ),
    );
  }
}

class AdminMobileRefreshButtonContainer extends StatelessWidget {
  final VoidCallback? onRefresh;
  final String tooltip;
  final bool isLoading;

  const AdminMobileRefreshButtonContainer({
    super.key,
    this.onRefresh,
    required this.tooltip,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AdminProRefreshButton(
        onRefresh: onRefresh,
        tooltip: tooltip,
        isDesktop: false,
        isLoading: isLoading,
      ),
    );
  }
}
