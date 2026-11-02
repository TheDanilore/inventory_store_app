import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AccountFormTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  static const types = [
    ('CAJA', 'Caja', Icons.point_of_sale_rounded),
    ('BANCO', 'Banco', Icons.account_balance_rounded),
    ('DIGITAL', 'Billetera', Icons.phone_android_rounded),
    ('OTRO', 'Otro', Icons.savings_rounded),
  ];

  const AccountFormTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final field = dark ? AppColors.darkBackground : AppColors.surface;
    final line = AppColors.brdSubtle(context);
    final title = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);
    final tealText = dark ? const Color(0xFF2DD4BF) : AppColors.tealDark;

    Widget typeTile((String, String, IconData) item) {
      final selected = selectedType == item.$1;
      return InkWell(
        onTap: () => onTypeChanged(item.$1),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.teal.withValues(alpha: 0.10) : field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.teal : line,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(item.$3, size: 20, color: selected ? tealText : muted),
              const SizedBox(height: 5),
              Text(
                item.$2,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? tealText : title,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: typeTile(types[i])),
        ],
      ],
    );
  }
}
