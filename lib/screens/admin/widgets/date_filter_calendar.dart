import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class DateFilterCalendar extends StatelessWidget {
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange> onDateRangeSelected;
  final VoidCallback onClear;

  const DateFilterCalendar({
    super.key,
    required this.dateRange,
    required this.onDateRangeSelected,
    required this.onClear,
  });

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

    return GestureDetector(
      onTap: () => _pickDateRange(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color:
              hasDate
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              hasDate
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 18,
              color: hasDate ? AppColors.primary : AppColors.textSecondary,
            ),
            if (hasDate) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
