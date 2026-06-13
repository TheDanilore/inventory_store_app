// ─── Botón de filtro de fecha (reutilizable) ─────────────────────────────────
import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class DateFilterButton extends StatelessWidget {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const DateFilterButton({
    super.key,
    required this.dateFrom,
    required this.dateTo,
    required this.onTap,
    required this.onClear,
  });

  String get _label {
    if (dateFrom == null && dateTo == null) return 'Fechas';
    final f =
        '${dateFrom!.day.toString().padLeft(2, '0')}/${dateFrom!.month.toString().padLeft(2, '0')}';
    final t =
        '${dateTo!.day.toString().padLeft(2, '0')}/${dateTo!.month.toString().padLeft(2, '0')}';
    return '$f–$t';
  }

  bool get _active => dateFrom != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 13,
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
