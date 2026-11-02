import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Selector desplegable para períodos de fecha predefinidos en el Kárdex.
class KardexDatePresetSelector extends StatelessWidget {
  final String activePreset;
  final ValueChanged<String> onSelected;

  const KardexDatePresetSelector({
    super.key,
    required this.activePreset,
    required this.onSelected,
  });

  static String getPresetLabel(String preset) {
    switch (preset) {
      case 'TODAY':
        return 'Hoy';
      case 'WEEK':
        return 'Últimos 7 días';
      case 'MONTH':
        return 'Este mes';
      case '30DAYS':
        return 'Últimos 30 días';
      case 'CUSTOM':
        return 'Personalizado';
      case 'ALL':
      default:
        return 'Todas las fechas';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Filtrar por período',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: AppColors.surface,
        onSelected: onSelected,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              getPresetLabel(activePreset),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        itemBuilder:
            (context) => [
              const PopupMenuItem(value: 'ALL', child: Text('Cualquier fecha')),
              const PopupMenuItem(value: 'TODAY', child: Text('Hoy')),
              const PopupMenuItem(value: 'WEEK', child: Text('Últimos 7 días')),
              const PopupMenuItem(
                value: 'MONTH',
                child: Text('Este mes actual'),
              ),
              const PopupMenuItem(
                value: '30DAYS',
                child: Text('Últimos 30 días'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'CUSTOM',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text('Rango personalizado...'),
                  ],
                ),
              ),
            ],
      ),
    );
  }
}
