import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class TypePill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const TypePill({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const DateFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class MovementsFilterToolbar extends StatelessWidget {
  final String typeFilter;
  final String dateFilter;
  final int totalCount;
  final int chargeCount;
  final int paymentCount;
  final void Function(String type) onTypeFilterChanged;
  final void Function(String date) onDateFilterChanged;

  const MovementsFilterToolbar({
    super.key,
    required this.typeFilter,
    required this.dateFilter,
    required this.totalCount,
    required this.chargeCount,
    required this.paymentCount,
    required this.onTypeFilterChanged,
    required this.onDateFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTotal =
        (chargeCount + paymentCount) > 0
            ? (chargeCount + paymentCount)
            : totalCount;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          TypePill(
            label: 'Todos',
            count: effectiveTotal,
            isSelected: typeFilter == 'ALL',
            onTap: () => onTypeFilterChanged('ALL'),
          ),
          const SizedBox(width: 8),
          TypePill(
            label: 'Abonos (-)',
            count: paymentCount,
            isSelected: typeFilter == 'PAYMENT',
            color: const Color(0xFF16A34A),
            onTap: () => onTypeFilterChanged('PAYMENT'),
          ),
          const SizedBox(width: 8),
          TypePill(
            label: 'Cargos (+)',
            count: chargeCount,
            isSelected: typeFilter == 'CHARGE',
            color: const Color(0xFFEA580C),
            onTap: () => onTypeFilterChanged('CHARGE'),
          ),

          const Spacer(),

          DateFilterChip(
            label: 'Todo',
            isSelected: dateFilter == 'all',
            onTap: () => onDateFilterChanged('all'),
          ),
          const SizedBox(width: 6),
          DateFilterChip(
            label: 'Este mes',
            isSelected: dateFilter == 'this_month',
            onTap: () => onDateFilterChanged('this_month'),
          ),
          const SizedBox(width: 6),
          DateFilterChip(
            label: 'Últimos 30 días',
            isSelected: dateFilter == '30_days',
            onTap: () => onDateFilterChanged('30_days'),
          ),
        ],
      ),
    );
  }
}
