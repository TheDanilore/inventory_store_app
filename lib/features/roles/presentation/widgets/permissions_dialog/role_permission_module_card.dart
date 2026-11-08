import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/permissions_dialog/role_permission_tile.dart';

class RolePermissionModuleCard extends StatelessWidget {
  final String module;
  final List<PermissionEntity> permissions;
  final Set<String> selectedPermissions;
  final VoidCallback onToggleModule;
  final ValueChanged<String> onTogglePermission;

  const RolePermissionModuleCard({
    super.key,
    required this.module,
    required this.permissions,
    required this.selectedPermissions,
    required this.onToggleModule,
    required this.onTogglePermission,
  });

  @override
  Widget build(BuildContext context) {
    final allSelected = permissions.every(
      (p) => selectedPermissions.contains(p.code),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de módulo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  module.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton(
                  onPressed: onToggleModule,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor:
                        allSelected ? Colors.grey.shade700 : AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(allSelected ? 'Desmarcar grupo' : 'Marcar grupo'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Lista de permisos de este módulo
          for (final p in permissions)
            RolePermissionTile(
              permission: p,
              isSelected: selectedPermissions.contains(p.code),
              onChanged: (_) => onTogglePermission(p.code),
            ),
        ],
      ),
    );
  }
}
