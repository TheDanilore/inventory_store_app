import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_components.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_role_info.dart';

class UserFormRolesSection extends StatelessWidget {
  final Set<String> selectedRoles;
  final ValueChanged<String> onToggleRole;

  const UserFormRolesSection({
    super.key,
    required this.selectedRoles,
    required this.onToggleRole,
  });

  @override
  Widget build(BuildContext context) {
    return UserFormSectionCard(
      title: 'Roles y permisos',
      subtitle: 'Puedes asignar uno o varios según sus responsabilidades.',
      icon: Icons.shield_outlined,
      children: [
        UserFormAdaptiveGrid(
          minItemWidth: 220,
          spacing: 10,
          children: [
            for (final r in UserFormRoleInfo.allRoles)
              UserFormRoleCard(
                info: r,
                isSelected: selectedRoles.contains(r.id),
                onTap: () => onToggleRole(r.id),
              ),
          ],
        ),
      ],
    );
  }
}
