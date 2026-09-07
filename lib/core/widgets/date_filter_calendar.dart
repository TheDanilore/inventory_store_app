import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class DateFilterCalendar extends StatelessWidget {
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange> onDateRangeSelected;
  final VoidCallback onClear;

  const DateFilterCalendar({
    super.key,
    required this.dateRange,
    required this.onDateRangeSelected,
    required this.onClear,
    this.isExpanded = false,
  });

  final bool isExpanded;

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // Bloqueado estrictamente hasta el día de hoy
      initialDateRange: dateRange,
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      onDateRangeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDate = dateRange != null;

    return Tooltip(
      message: 'Filtrar por rango de fechas',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _pickDateRange(context),
          child: Container(
            height: isExpanded ? null : 36,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isExpanded ? 10 : 0,
            ),
            alignment: isExpanded ? null : Alignment.center,
            decoration: BoxDecoration(
              color:
                  hasDate
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    hasDate
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.border,
                width: hasDate ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: hasDate ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                if (isExpanded)
                  Expanded(
                    child: Text(
                      hasDate
                          ? '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year} - ${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}'
                          : 'Seleccionar fechas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            hasDate
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Text(
                    hasDate
                        ? '${dateRange!.start.day}/${dateRange!.start.month} - ${dateRange!.end.day}/${dateRange!.end.month}'
                        : 'Fechas',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          hasDate ? FontWeight.w800 : FontWeight.w600,
                      color:
                          hasDate
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                  ),
                if (hasDate) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
