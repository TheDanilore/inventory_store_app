import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_components.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_role_info.dart';

class UserFormSummaryHeader extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final bool isEditing;
  final Set<String> selectedRoles;

  const UserFormSummaryHeader({
    super.key,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.isEditing,
    required this.selectedRoles,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([nameCtrl, emailCtrl]),
      builder: (context, _) {
        final name = nameCtrl.text.trim();
        final email = emailCtrl.text.trim();
        final roles =
            UserFormRoleInfo.allRoles
                .where((r) => selectedRoles.contains(r.id))
                .toList();

        final title =
            name.isNotEmpty
                ? name
                : (isEditing ? 'Colaborador' : 'Nuevo colaborador');
        final subtitle =
            email.isNotEmpty
                ? email
                : (isEditing
                    ? 'Modifica los datos, los roles y el estado de acceso.'
                    : 'Completa los datos para crear su cuenta de acceso.');

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: userFormCardDecoration(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserFormInitialsAvatar(name: name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        UserFormModePill(isEditing: isEditing),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                    if (roles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in roles) UserFormRoleChip(info: r),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
