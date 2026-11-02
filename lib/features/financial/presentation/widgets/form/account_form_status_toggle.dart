import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AccountFormStatusToggle extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool> onToggleActive;

  const AccountFormStatusToggle({
    super.key,
    required this.isActive,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final field = dark ? AppColors.darkBackground : AppColors.surface;
    final line = AppColors.brdSubtle(context);
    final title = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta activa',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Disponible para cobros y pagos'
                      : 'No aparecerá en nuevos registros',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: onToggleActive,
            activeTrackColor: AppColors.teal,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
