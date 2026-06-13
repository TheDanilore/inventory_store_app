import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class DateFilterButton extends StatelessWidget {
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange> onDateRangeSelected;
  final VoidCallback onClear;

  const DateFilterButton({
    super.key,
    required this.dateRange,
    required this.onDateRangeSelected,
    required this.onClear,
  });

  String get _label {
    if (dateRange == null) return 'Fechas';
    final f =
        '${dateRange!.start.day.toString().padLeft(2, '0')}/${dateRange!.start.month.toString().padLeft(2, '0')}';
    final t =
        '${dateRange!.end.day.toString().padLeft(2, '0')}/${dateRange!.end.month.toString().padLeft(2, '0')}';
    return '$f–$t';
  }

  bool get _active => dateRange != null;

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      // 👇 Restringimos el límite máximo al día exacto de hoy
      lastDate: now,
      initialDateRange: dateRange,
      initialEntryMode: DatePickerEntryMode.input,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onDateRangeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickDateRange(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color:
              _active
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _active ? AppColors.primary : Colors.grey.shade300,
            width: _active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: _active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (_active) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  // Evitar que el tap en "cerrar" también abra el calendario
                  onClear();
                },
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
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
    );
  }
}
