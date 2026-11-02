import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Barra de filtros segmentados de alto rendimiento para el directorio de clientes.
///
/// Soporta pestañas para 'Todos', 'Con deuda activa' y '👑 Top VIP',
/// con badges reactivos y estilos adaptados a temas claros y oscuros.
class CustomersSegmentedFilter extends StatelessWidget {
  final int selectedIndex;
  final int totalCount;
  final int debtCount;
  final int topCount;
  final ValueChanged<int> onTabSelected;

  const CustomersSegmentedFilter({
    super.key,
    required this.selectedIndex,
    required this.totalCount,
    required this.debtCount,
    required this.topCount,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            title: 'Todos',
            count: totalCount,
            isSelected: selectedIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(width: 4),
          _SegmentButton(
            title: 'Con deuda activa',
            count: debtCount,
            isSelected: selectedIndex == 1,
            isAlert: debtCount > 0,
            onTap: () => onTabSelected(1),
          ),
          const SizedBox(width: 4),
          _SegmentButton(
            title: '👑 Top VIP',
            count: topCount,
            isSelected: selectedIndex == 2,
            isGold: true,
            onTap: () => onTabSelected(2),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String title;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAlert;
  final bool isGold;

  const _SegmentButton({
    required this.title,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.isAlert = false,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? (isGold ? AppColors.warningDark : AppColors.primary)
                        : AppColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color:
                      isAlert
                          ? AppColors.error
                          : (isGold
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : (isSelected
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.border)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color:
                        isAlert
                            ? Colors.white
                            : (isGold
                                ? AppColors.warningDark
                                : (isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary)),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
