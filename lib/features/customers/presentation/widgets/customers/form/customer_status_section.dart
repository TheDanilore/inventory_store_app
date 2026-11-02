import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_form_fields.dart';

/// Sección de activación/desactivación del estado del cliente
class CustomerStatusSection extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool> onChanged;

  const CustomerStatusSection({
    super.key,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomerSectionHeader(icon: Icons.tune_rounded, title: 'Estado'),
        const SizedBox(height: 12),
        CustomerToggleRow(
          icon: Icons.circle,
          iconColor: isActive ? AppColors.success : AppColors.textMuted,
          title: isActive ? 'Cliente activo' : 'Cliente inactivo',
          subtitle:
              isActive ? 'Puede realizar compras' : 'No puede realizar compras',
          value: isActive,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
