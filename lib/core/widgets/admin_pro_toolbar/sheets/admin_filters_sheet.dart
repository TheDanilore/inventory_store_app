import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/components/admin_filter_chip.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/models/admin_toolbar_models.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar/sheets/admin_filter_select_field.dart';

/// Bottom sheet modal para filtros en móvil y tablet:
/// Chips agrupados, estado reactivo en vivo y micro-animaciones escalonadas.
class AdminFiltersSheet extends StatelessWidget {
  final String title;
  final ValueNotifier<FiltersSnapshot> snapshot;
  final VoidCallback? onClearAll;

  const AdminFiltersSheet({
    super.key,
    required this.title,
    required this.snapshot,
    this.onClearAll,
  });

  void _clear(FiltersSnapshot s) {
    AppFeedbackService.selectionClick();
    if (onClearAll != null) {
      onClearAll!();
      return;
    }
    for (final g in s.groups) {
      if (g.isActive) g.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ValueListenableBuilder<FiltersSnapshot>(
        valueListenable: snapshot,
        builder: (context, s, _) {
          final activeCount = s.groups.where((g) => g.isActive).length;
          final hasGroups = s.groups.isNotEmpty;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (activeCount > 0 || onClearAll != null)
                      TextButton(
                        onPressed: () => _clear(s),
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: AppColors.textMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...s.groups.asMap().entries.map((entry) {
                        final index = entry.key;
                        final g = entry.value;
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 180 + index * 40),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, val, child) {
                            return Opacity(
                              opacity: val,
                              child: Transform.translate(
                                offset: Offset(0, (1.0 - val) * 8),
                                child: child,
                              ),
                            );
                          },
                          child: FilterGroupSection(group: g),
                        );
                      }),
                      // Respaldo para widgets legados
                      if (!hasGroups)
                        for (final w in s.legacyWidgets)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: w,
                          ),
                      if (s.extras.isNotEmpty)
                        TweenAnimationBuilder<double>(
                          duration: Duration(
                            milliseconds: 180 + s.groups.length * 40,
                          ),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, val, child) {
                            return Opacity(
                              opacity: val,
                              child: Transform.translate(
                                offset: Offset(0, (1.0 - val) * 8),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'FECHAS',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    if (s.extras.any(
                                      (w) =>
                                          w is DateFilterCalendar &&
                                          w.dateRange != null,
                                    )) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                for (final w in s.extras)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: w,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    s.applyLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sección de grupo de filtros dentro del modal bottom sheet.
class FilterGroupSection extends StatelessWidget {
  final AdminFilterGroup<dynamic> group;

  const FilterGroupSection({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool useSelect =
        group.displayType == AdminFilterDisplayType.select ||
        (group.displayType == AdminFilterDisplayType.auto &&
            group.options.length > 4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AppColors.textMuted,
                ),
              ),
              if (group.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (useSelect)
            AdminFilterSelectField(group: group, isDark: isDark)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in group.options)
                  AdminFilterChip(
                    option: o,
                    selected: group.isSelected(o.value),
                    isDark: isDark,
                    onTap: () {
                      AppFeedbackService.selectionClick();
                      group.select(o.value);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
