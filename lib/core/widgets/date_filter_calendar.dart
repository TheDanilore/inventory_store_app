import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

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

  const DateFilterCalendar({
    super.key,
    required this.dateRange,
    required this.onDateRangeSelected,
    required this.onClear,
    this.isExpanded = false,
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
      initialDateRange: dateRange,
      helpText: 'SELECCIONA EL PERÍODO',
      saveText: 'APLICAR',
      cancelText: 'CANCELAR',
      builder: (context, child) {
        final isDesktop = MediaQuery.of(context).size.width >= 650;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          child:
              isDesktop
                  ? Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 520,
                        maxHeight: 560,
                      ),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 36,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: child!,
                    ),
                  )
                  : child!,
        );
      },
    );

    if (picked != null) {
      onDateRangeSelected(picked);
    }
  }

  void _showAdaptivePicker(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 650;
    if (isDesktop) {
      _showDesktopDialog(context);
    } else {
      _showMobileSheet(context);
    }
  }

  void _showDesktopDialog(BuildContext context) {
    final presets = _buildPresets();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filtrar por Período',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Selecciona un acceso rápido o personalizado',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                // Lista de Presets
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      ...presets.map((preset) {
                        final isSelected =
                            dateRange != null &&
                            _isRangeEqual(preset.range, dateRange!);

                        return _PresetTile(
                          preset: preset,
                          isSelected: isSelected,
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            onDateRangeSelected(preset.range);
                          },
                        );
                      }),
                      const SizedBox(height: 4),

                      // Botón Personalizado
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          _openCustomPicker(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                              style: BorderStyle.solid,
                            ),
                            color: const Color(0xFFF8FAFC),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.edit_calendar_rounded,
                                size: 18,
                                color: AppColors.teal,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Rango personalizado...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer (si hay filtro activo para limpiar)
                if (dateRange != null) ...[
                  const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        onClear();
                      },
                      icon: const Icon(
                        Icons.clear_all_rounded,
                        size: 16,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'Restablecer período (Ver todo)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMobileSheet(BuildContext context) {
    final presets = _buildPresets();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.primary,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Filtrar por Período',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (dateRange != null)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          onClear();
                        },
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lista de Presets Rápidos
                ...presets.map((preset) {
                  final isSelected =
                      dateRange != null &&
                      _isRangeEqual(preset.range, dateRange!);

                  return _PresetTile(
                    preset: preset,
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onDateRangeSelected(preset.range);
                    },
                  );
                }),
                const SizedBox(height: 6),

                // Botón Personalizado
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openCustomPicker(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 18,
                          color: AppColors.teal,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Rango personalizado...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDate = dateRange != null;
    final String label = _getRangeLabel();

    return Tooltip(
      message: 'Filtrar por período',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showAdaptivePicker(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
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
                      : Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: hasDate ? AppColors.primary : AppColors.textSecondary,
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
                      fontWeight: hasDate ? FontWeight.w800 : FontWeight.w600,
                      color:
                          hasDate
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                  ),
                if (hasDate) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ] else ...[
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
    );
  }
}

/// Elemento de lista para cada preset dentro del selector de fechas
class _PresetTile extends StatelessWidget {
  final _DatePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      )
                      : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    preset.icon,
                    size: 16,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        preset.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isSelected
                                  ? AppColors.primary.withValues(alpha: 0.75)
                                  : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
