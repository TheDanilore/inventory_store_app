import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';

class AccountFormEntityPicker extends StatelessWidget {
  final String brandKey;
  final ValueChanged<FinancialBrandPreset> onSelectPreset;
  final VoidCallback onSelectCustom;
  final VoidCallback onShowAll;

  static const _quickKeys = [
    'caja_principal',
    'yape',
    'plin',
    'bcp',
    'bbva',
    'interbank',
  ];
  static const int _fallbackVisible = 5;

  const AccountFormEntityPicker({
    super.key,
    required this.brandKey,
    required this.onSelectPreset,
    required this.onSelectCustom,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final field = dark ? AppColors.darkBackground : AppColors.surface;
    final line = AppColors.brdSubtle(context);
    final title = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);
    final tealText = dark ? const Color(0xFF2DD4BF) : AppColors.tealDark;

    final all = FinancialBrandHelper.presets;
    var visible = <FinancialBrandPreset>[
      for (final k in _quickKeys) ...all.where((p) => p.key == k),
    ];
    if (visible.isEmpty) visible = all.take(_fallbackVisible).toList();

    final selected = all.where((p) => p.key == brandKey).firstOrNull;
    if (selected != null && visible.every((p) => p.key != selected.key)) {
      visible = [...visible, selected];
    }
    final hidden = all.length - visible.length;

    Widget entityChip({
      required bool isSelected,
      required Color color,
      required Widget leading,
      required String label,
      required VoidCallback onTap,
      String? trailing,
    }) {
      final fg =
          isSelected
              ? (dark ? Color.lerp(color, Colors.white, 0.4)! : color)
              : title;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : field,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : line,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 5),
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in visible)
          entityChip(
            isSelected: brandKey == p.key,
            color: p.primaryColor,
            leading: FinancialBrandHelper.buildBrandBadge(
              name: p.label,
              type: p.type,
              brandKey: p.key,
              size: 22,
            ),
            label: p.label,
            onTap: () => onSelectPreset(p),
          ),
        entityChip(
          isSelected: brandKey == 'auto',
          color: AppColors.teal,
          leading: Icon(
            Icons.edit_note_rounded,
            size: 20,
            color: brandKey == 'auto' ? tealText : muted,
          ),
          label: 'Otro',
          onTap: onSelectCustom,
        ),
        if (hidden > 0)
          entityChip(
            isSelected: false,
            color: AppColors.teal,
            leading: Icon(Icons.search_rounded, size: 18, color: muted),
            label: 'Ver todas',
            trailing: '+$hidden',
            onTap: onShowAll,
          ),
      ],
    );
  }
}
