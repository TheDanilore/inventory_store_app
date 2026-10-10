import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_date_range_picker_modal.dart';

/// Preset de rango de fecha para selección rápida (Stripe / Linear style).
class _DatePreset {
  final String label;
  final String subtitle;
  final IconData icon;
  final DateTimeRange range;

  const _DatePreset({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.range,
  });
}

/// Selector de fechas "Camaleónico" y adaptativo:
/// - Desktop (>= 650px): Diálogo modal compacto con presets rápidos y selector embebido
/// - Mobile (< 650px): Apple HIG Modal BottomSheet con accesos táctiles 1-tap
/// - Botón exterior inteligente que muestra nombres semánticos ("Hoy", "Este mes", etc.)
class DateFilterCalendar extends StatelessWidget {
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange> onDateRangeSelected;
  final VoidCallback onClear;
  final bool isExpanded;
  final double? height;
  final BorderRadius? borderRadius;

  const DateFilterCalendar({
    super.key,
    required this.dateRange,
    required this.onDateRangeSelected,
    required this.onClear,
    this.isExpanded = false,
    this.height,
    this.borderRadius,
  });

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isRangeEqual(DateTimeRange a, DateTimeRange b) {
    return _isSameDay(a.start, b.start) && _isSameDay(a.end, b.end);
  }

  static String _monthShort(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  static String _monthFull(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  List<_DatePreset> _buildPresets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final past7 = today.subtract(const Duration(days: 6));
    final firstOfThisMonth = DateTime(today.year, today.month, 1);
    final lastOfPrevMonth = firstOfThisMonth.subtract(const Duration(days: 1));
    final firstOfPrevMonth = DateTime(
      lastOfPrevMonth.year,
      lastOfPrevMonth.month,
      1,
    );

    return [
      _DatePreset(
        label: 'Hoy',
        subtitle: '${today.day} de ${_monthFull(today.month)}',
        icon: Icons.today_rounded,
        range: DateTimeRange(start: today, end: today),
      ),
      _DatePreset(
        label: 'Ayer',
        subtitle: '${yesterday.day} de ${_monthFull(yesterday.month)}',
        icon: Icons.history_rounded,
        range: DateTimeRange(start: yesterday, end: yesterday),
      ),
      _DatePreset(
        label: 'Últimos 7 días',
        subtitle:
            '${past7.day} ${_monthShort(past7.month)} - ${today.day} ${_monthShort(today.month)}',
        icon: Icons.date_range_rounded,
        range: DateTimeRange(start: past7, end: today),
      ),
      _DatePreset(
        label: 'Este mes',
        subtitle: '1 - ${today.day} ${_monthShort(today.month)}',
        icon: Icons.calendar_month_rounded,
        range: DateTimeRange(start: firstOfThisMonth, end: today),
      ),
      _DatePreset(
        label: 'Mes anterior',
        subtitle:
            '1 - ${lastOfPrevMonth.day} ${_monthShort(lastOfPrevMonth.month)}',
        icon: Icons.event_repeat_rounded,
        range: DateTimeRange(start: firstOfPrevMonth, end: lastOfPrevMonth),
      ),
    ];
  }

  String _getRangeLabel() {
    if (dateRange == null) {
      return isExpanded ? 'Seleccionar fechas' : 'Fechas';
    }

    final presets = _buildPresets();
    for (final preset in presets) {
      if (_isRangeEqual(preset.range, dateRange!)) {
        return preset.label;
      }
    }

    // Formato personalizado
    final start = dateRange!.start;
    final end = dateRange!.end;
    if (_isSameDay(start, end)) {
      return '${start.day} ${_monthShort(start.month)}';
    } else if (start.month == end.month && start.year == end.year) {
      return '${start.day} - ${end.day} ${_monthShort(start.month)}';
    } else {
      return '${start.day}/${start.month} - ${end.day}/${end.month}';
    }
  }

  Future<void> _openCustomPicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await AppDateRangePickerModal.show(
      context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialStartDate: dateRange?.start,
      initialEndDate: dateRange?.end,
    );

    if (picked != null) {
      onDateRangeSelected(picked);
    }
  }

  void _showAdaptivePicker(BuildContext context) {
    _openCustomPicker(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDate = dateRange != null;
    final String label = _getRangeLabel();

    return Tooltip(
      message: 'Filtrar por período',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isExpanded ? null : (height ?? 36),
        padding: EdgeInsets.only(
          left: 12,
          right: hasDate ? 6 : 10,
          top: isExpanded ? 10 : 0,
          bottom: isExpanded ? 10 : 0,
        ),
        alignment: isExpanded ? null : Alignment.center,
        decoration: BoxDecoration(
          color:
              hasDate ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          border: Border.all(
            color:
                hasDate
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
            width: hasDate ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Área principal: abre el selector adaptativo
            Flexible(
              fit: isExpanded ? FlexFit.tight : FlexFit.loose,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAdaptivePicker(context),
                  child: Row(
                    mainAxisSize:
                        isExpanded ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color:
                            hasDate
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      if (isExpanded)
                        Expanded(
                          child: Text(
                            label,
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
                          label,
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
                      if (!hasDate) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Botón independiente para limpiar filtro (X)
            if (hasDate) ...[
              const SizedBox(width: 6),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
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
