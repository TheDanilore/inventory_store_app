import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class OrdersFilterDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const OrdersFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            isDense: true,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
