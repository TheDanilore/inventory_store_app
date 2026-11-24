import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class SupplierCreditsSegmentedFilter extends StatelessWidget {
  final int selectedIndex;
  final int debtCount;
  final ValueChanged<int> onSelectTab;

  const SupplierCreditsSegmentedFilter({
    super.key,
    required this.selectedIndex,
    required this.debtCount,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterTabButton(
              title: 'Todas',
              shortcutHint: '1',
              isSelected: selectedIndex == 0,
              onTap: () => onSelectTab(0),
            ),
            const SizedBox(width: 4),
            _FilterTabButton(
              title: 'Por Pagar',
              count: debtCount,
              shortcutHint: '2',
              isSelected: selectedIndex == 1,
              onTap: () => onSelectTab(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  final String title;
  final int? count;
  final String shortcutHint;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTabButton({
    required this.title,
    this.count,
    required this.shortcutHint,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
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
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.danger : AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shortcutHint,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
