import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';

/// Modal corporativo de selección de rango de fechas para el ERP.
/// Inspirado en diseños modernos de Linear, Stripe y Apple HIG.
class AppDateRangePickerModal extends StatefulWidget {
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const AppDateRangePickerModal({
    super.key,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.firstDate,
    required this.lastDate,
  });

  /// Abre el selector de fechas de manera responsiva (Dialog en Desktop/Tablet, BottomSheet en Mobile).
  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? initialStartDate,
    DateTime? initialEndDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final effectiveStart = initialStartDate ?? now.subtract(const Duration(days: 7));
    final effectiveEnd = initialEndDate ?? now;
    final effectiveFirst = firstDate ?? DateTime(2020, 1, 1);
    final effectiveLast = lastDate ?? now.add(const Duration(days: 365));

    final isDesktop = MediaQuery.of(context).size.width >= 680;

    if (isDesktop) {
      return showDialog<DateTimeRange>(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.white,
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 780,
                maxHeight: 580,
              ),
              child: AppDateRangePickerModal(
                initialStartDate: effectiveStart,
                initialEndDate: effectiveEnd,
                firstDate: effectiveFirst,
                lastDate: effectiveLast,
              ),
            ),
          );
        },
      );
    } else {
      return showModalBottomSheet<DateTimeRange>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            child: SafeArea(
              child: AppDateRangePickerModal(
                initialStartDate: effectiveStart,
                initialEndDate: effectiveEnd,
                firstDate: effectiveFirst,
                lastDate: effectiveLast,
              ),
            ),
          );
        },
      );
    }
  }

  @override
  State<AppDateRangePickerModal> createState() => _AppDateRangePickerModalState();
}

class _AppDateRangePickerModalState extends State<AppDateRangePickerModal> {
  late DateTime _startDate;
  late DateTime? _endDate;
  late DateTime _displayedMonth;
  DateTime? _hoveredDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(
      widget.initialStartDate.year,
      widget.initialStartDate.month,
      widget.initialStartDate.day,
    );
    _endDate = DateTime(
      widget.initialEndDate.year,
      widget.initialEndDate.month,
      widget.initialEndDate.day,
    );
    _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
  }

  void _triggerHaptic() {
    if (!kIsWeb) {
      Vibration.vibrate(duration: 25, amplitude: 60);
    }
  }

  void _onDayTapped(DateTime day) {
    _triggerHaptic();
    setState(() {
      if (_endDate != null) {
        // Reiniciar selección con un nuevo punto de inicio
        _startDate = day;
        _endDate = null;
      } else {
        // Segundo clic: definir fin del rango
        if (day.isBefore(_startDate)) {
          _startDate = day;
          _endDate = null;
        } else {
          _endDate = day;
        }
      }
    });
  }

  void _applyPreset(DateTime start, DateTime end) {
    _triggerHaptic();
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day);
      _displayedMonth = DateTime(_startDate.year, _startDate.month, 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInRange(DateTime date, DateTime start, DateTime end) {
    return (date.isAfter(start) || _isSameDay(date, start)) &&
        (date.isBefore(end) || _isSameDay(date, end));
  }

  int get _selectedDaysCount {
    if (_endDate == null) return 1;
    return _endDate!.difference(_startDate).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 680;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. HEADER ──────────────────────────────────────────────────────────
        _buildHeader(context),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // ── 2. BODY (Two Columns on Desktop / Stacked on Mobile) ───────────────
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Interactive Month Calendar
                        Expanded(
                          flex: 11,
                          child: _buildCalendarView(),
                        ),
                        const SizedBox(width: 24),
                        // Vertical Divider
                        Container(
                          width: 1,
                          height: 380,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 24),
                        // Right Column: Presets & Explicit Date Inputs
                        Expanded(
                          flex: 9,
                          child: _buildPresetsAndInputs(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPresetsChips(isMobile: true),
                        const SizedBox(height: 16),
                        _buildDateInputCards(),
                        const SizedBox(height: 20),
                        _buildCalendarView(),
                      ],
                    ),
            ),
          ),
        ),

        // ── 3. FOOTER ──────────────────────────────────────────────────────────
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        _buildFooter(context),
      ],
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.date_range_rounded,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rango de Fechas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Selecciona el período para filtrar las métricas y registros',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            tooltip: 'Cerrar',
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ── CALENDAR VIEW ───────────────────────────────────────────────────────────
  Widget _buildCalendarView() {
    final monthTitle = DateFormat('MMMM yyyy', 'es').format(_displayedMonth);
    final capitalizedMonth =
        monthTitle[0].toUpperCase() + monthTitle.substring(1);

    final canGoPrev = _displayedMonth.isAfter(
      DateTime(widget.firstDate.year, widget.firstDate.month, 1),
    );
    final canGoNext = _displayedMonth.isBefore(
      DateTime(widget.lastDate.year, widget.lastDate.month, 1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation Row: < Mes Año >
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: canGoPrev ? _prevMonth : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                color: const Color(0xFF334155),
                disabledColor: const Color(0xFFCBD5E1),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                capitalizedMonth,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                onPressed: canGoNext ? _nextMonth : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                color: const Color(0xFF334155),
                disabledColor: const Color(0xFFCBD5E1),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Weekdays Header: LU MA MI JU VI SA DO
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _WeekdayLabel('LU'),
            _WeekdayLabel('MA'),
            _WeekdayLabel('MI'),
            _WeekdayLabel('JU'),
            _WeekdayLabel('VI'),
            _WeekdayLabel('SA'),
            _WeekdayLabel('DO'),
          ],
        ),
        const SizedBox(height: 8),

        // Days Grid
        _buildDaysGrid(),
      ],
    );
  }

  Widget _buildDaysGrid() {
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    // Monday = 1, Sunday = 7
    final startingWeekday = firstDayOfMonth.weekday; // 1 to 7

    // Days from previous month to pad the first row
    final prevMonthLastDay = DateTime(_displayedMonth.year, _displayedMonth.month, 0).day;
    final leadingDaysCount = startingWeekday - 1;

    final totalGridCells = ((leadingDaysCount + daysInMonth) / 7).ceil() * 7;

    final effectiveEnd = _endDate ?? (_hoveredDate != null && _hoveredDate!.isAfter(_startDate) ? _hoveredDate : _startDate);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalGridCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 0,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        if (index < leadingDaysCount) {
          // Trailing days from previous month
          final dayNum = prevMonthLastDay - (leadingDaysCount - 1 - index);
          return Center(
            child: Text(
              '$dayNum',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        final dayNum = index - leadingDaysCount + 1;
        if (dayNum > daysInMonth) {
          // Leading days from next month
          final nextMonthDay = dayNum - daysInMonth;
          return Center(
            child: Text(
              '$nextMonthDay',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }

        final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
        final isStart = _isSameDay(cellDate, _startDate);
        final isEnd = effectiveEnd != null && _isSameDay(cellDate, effectiveEnd);
        final isBetween = effectiveEnd != null &&
            _isInRange(cellDate, _startDate, effectiveEnd) &&
            !isStart &&
            !isEnd;
        final isSingleDay = isStart && isEnd;
        final isSelectable = !cellDate.isBefore(widget.firstDate) &&
            !cellDate.isAfter(widget.lastDate);

        return MouseRegion(
          onEnter: (_) {
            if (_endDate == null && cellDate.isAfter(_startDate)) {
              setState(() => _hoveredDate = cellDate);
            }
          },
          onExit: (_) {
            if (_hoveredDate != null) {
              setState(() => _hoveredDate = null);
            }
          },
          child: GestureDetector(
            onTap: isSelectable ? () => _onDayTapped(cellDate) : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Range highlight band background
                if ((isStart && effectiveEnd != null && !isSingleDay) ||
                    (isEnd && !isSingleDay) ||
                    isBetween)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.horizontal(
                          left: isStart ? const Radius.circular(20) : Radius.zero,
                          right: isEnd ? const Radius.circular(20) : Radius.zero,
                        ),
                      ),
                    ),
                  ),

                // Day Cell Indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (isStart || isEnd)
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: (isStart || isEnd)
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: (isStart || isEnd)
                          ? FontWeight.w700
                          : (isBetween ? FontWeight.w600 : FontWeight.w500),
                      color: (isStart || isEnd)
                          ? Colors.white
                          : (isBetween
                              ? const Color(0xFF1E40AF)
                              : (isSelectable
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFCBD5E1))),
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

  // ── RIGHT COLUMN: PRESETS & INPUTS ──────────────────────────────────────────
  Widget _buildPresetsAndInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Atajos rápidos',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        _buildPresetsChips(isMobile: false),
        const SizedBox(height: 20),
        const Text(
          'Período activo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        _buildDateInputCards(),
        const SizedBox(height: 14),

        // Summary duration chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.timelapse_rounded,
                size: 16,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duración: $_selectedDaysCount ${_selectedDaysCount == 1 ? "día" : "días"} seleccionados',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsChips({required bool isMobile}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final startOf7Days = today.subtract(const Duration(days: 6));
    final startOfMonth = DateTime(today.year, today.month, 1);
    final endOfMonth = DateTime(today.year, today.month + 1, 0);
    final startOf30Days = today.subtract(const Duration(days: 29));
    final startOfYear = DateTime(today.year, 1, 1);
    final startOfAll = DateTime(2020, 1, 1);

    final presets = [
      ('Hoy', today, today),
      ('Ayer', yesterday, yesterday),
      ('Esta semana', startOfWeek, endOfWeek),
      ('Últimos 7 días', startOf7Days, today),
      ('Este mes', startOfMonth, endOfMonth),
      ('Últimos 30 días', startOf30Days, today),
      ('Año actual', startOfYear, today),
      ('Histórico', startOfAll, today),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.map((p) {
        final label = p.$1;
        final start = p.$2;
        final end = p.$3;

        final isSelected = _isSameDay(_startDate, start) &&
            _endDate != null &&
            _isSameDay(_endDate!, end);

        return InkWell(
          onTap: () => _applyPreset(start, end),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateInputCards() {
    final startStr = DateFormat('dd/MM/yyyy', 'es').format(_startDate);
    final endStr = _endDate != null
        ? DateFormat('dd/MM/yyyy', 'es').format(_endDate!)
        : 'Selecciona fin...';

    return Row(
      children: [
        // Start date input card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Desde',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  startStr,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // End date input card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _endDate == null
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Hasta',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  endStr,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _endDate == null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── FOOTER ──────────────────────────────────────────────────────────────────
  Widget _buildFooter(BuildContext context) {
    final effectiveEnd = _endDate ?? _startDate;
    final summaryText =
        '${DateFormat("d MMM, yyyy", "es").format(_startDate)} – ${DateFormat("d MMM, yyyy", "es").format(effectiveEnd)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          // Selected summary on left
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    summaryText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Cancel button
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),

          // Apply button
          FilledButton.icon(
            onPressed: () {
              _triggerHaptic();
              final result = DateTimeRange(
                start: _startDate,
                end: effectiveEnd,
              );
              Navigator.of(context).pop(result);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Aplicar filtro'),
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
