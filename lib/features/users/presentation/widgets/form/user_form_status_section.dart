import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_components.dart';

class UserFormStatusSection extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool> onToggleActive;

  const UserFormStatusSection({
    super.key,
    required this.isActive,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green.shade700 : Colors.red.shade700;
    return UserFormSectionCard(
      title: 'Estado de la cuenta',
      subtitle: 'Controla si puede iniciar sesión.',
      icon: Icons.verified_user_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? 'Cuenta activa' : 'Cuenta inactiva',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? 'Puede iniciar sesión y operar.'
                        : 'Acceso suspendido hasta reactivarla.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Switch(
              value: isActive,
              activeThumbColor: AppColors.primary,
              onChanged: onToggleActive,
            ),
          ],
        ),
      ],
    );
  }
}
