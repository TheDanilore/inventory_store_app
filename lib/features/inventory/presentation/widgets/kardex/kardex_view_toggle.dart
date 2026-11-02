import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Control segmentado de conmutación de vista (Cards Línea de Tiempo vs Tabla Libro Mayor).
class KardexViewToggle extends StatelessWidget {
  final bool isLedgerView;
  final ValueChanged<bool> onToggleView;

  const KardexViewToggle({
    super.key,
    required this.isLedgerView,
    required this.onToggleView,
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
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewToggleButton(
            icon: Icons.view_agenda_outlined,
            tooltip: 'Vista Línea de Tiempo',
            isSelected: !isLedgerView,
            onTap: () => onToggleView(false),
          ),
          _ViewToggleButton(
            icon: Icons.table_chart_outlined,
            tooltip: 'Vista Libro Mayor (Ledger)',
            isSelected: isLedgerView,
            onTap: () => onToggleView(true),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected ? AppColors.cardShadow(opacity: 0.04) : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
