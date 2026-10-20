import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';
import 'package:inventory_store_app/features/roles/presentation/bloc/roles_cubit.dart';
import 'package:inventory_store_app/features/roles/presentation/bloc/roles_state.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/role_form_dialog.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/role_permissions_dialog.dart';

class RolesManagementView extends StatefulWidget {
  const RolesManagementView({super.key});

  @override
  State<RolesManagementView> createState() => _RolesManagementViewState();
}

class _RolesManagementViewState extends State<RolesManagementView> {
  @override
  void initState() {
    super.initState();
    context.read<RolesCubit>().loadRolesAndPermissions();
  }

  Color _getRoleColor(String name) {
    switch (name) {
      case 'admin':
        return Colors.indigo;
      case 'cashier':
        return AppColors.teal;
      case 'warehouse_keeper':
        return Colors.purple.shade600;
      case 'employee':
        return Colors.orange.shade700;
      case 'customer':
        return AppColors.primary;
      default:
        return Colors.blueGrey.shade700;
    }
  }

  IconData _getRoleIcon(String name) {
    switch (name) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'cashier':
        return Icons.point_of_sale_rounded;
      case 'warehouse_keeper':
        return Icons.inventory_2_rounded;
      case 'employee':
        return Icons.badge_rounded;
      case 'customer':
        return Icons.person_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  void _openPermissionsDialog(RoleWithPermissions role, RolesState state) {
    RolePermissionsDialog.show(
      context: context,
      role: role,
      allPermissions: state.allPermissions,
      onSave: (codes) async {
        final success = await context.read<RolesCubit>().syncPermissions(
          roleId: role.id,
          permissionCodes: codes,
        );
        if (success && mounted) {
          AppSnackbar.show(
            context,
            message: 'Permisos del rol "${role.name}" guardados correctamente.',
            type: SnackbarType.success,
          );
        }
        return success;
      },
    );
  }

  void _openCreateRoleDialog() {
    RoleFormDialog.show(
      context: context,
      onSave: (name, description) async {
        final success = await context.read<RolesCubit>().createRole(
          name: name,
          description: description,
        );
        if (success && mounted) {
          AppSnackbar.show(
            context,
            message: 'Rol "$name" creado correctamente.',
            type: SnackbarType.success,
          );
        }
        return success;
      },
    );
  }

  void _openEditRoleDialog(RoleWithPermissions role) {
    RoleFormDialog.show(
      context: context,
      existingRole: role,
      onSave: (name, description) async {
        final success = await context.read<RolesCubit>().updateRole(
          id: role.id,
          name: name,
          description: description,
        );
        if (success && mounted) {
          AppSnackbar.show(
            context,
            message: 'Rol "$name" actualizado correctamente.',
            type: SnackbarType.success,
          );
        }
        return success;
      },
    );
  }

  Future<void> _confirmDeleteRole(RoleWithPermissions role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('¿Eliminar rol "${role.name}"?'),
            content: const Text(
              'Esta acción desvinculará este rol de todos los usuarios asignados y no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<RolesCubit>().deleteRole(role.id);
      if (success && mounted) {
        AppSnackbar.show(
          context,
          message: 'Rol eliminado con éxito.',
          type: SnackbarType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RolesCubit, RolesState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => context.read<RolesCubit>().loadRolesAndPermissions(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera de la sección ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Roles y Permisos del Sistema',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Define qué acciones puede ejecutar cada miembro del equipo en el ERP y POS.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _openCreateRoleDialog,
                      icon: const Icon(Icons.add_moderator_rounded, size: 18),
                      label: const Text('Nuevo Rol'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Lista de Roles ──────────────────────────────────────────
                if (state.roles.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No hay roles configurados.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.roles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final role = state.roles[index];
                      final roleColor = _getRoleColor(role.name);
                      final roleIcon = _getRoleIcon(role.name);
                      final totalPerms = state.allPermissions.length;
                      final assignedPerms = role.permissions.length;

                      // Determinar módulos presentes en este rol
                      final activeModules = <String>{};
                      for (final code in role.permissions) {
                        activeModules.add(AppPermissions.getModule(code));
                      }

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ícono del Rol
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    roleIcon,
                                    color: roleColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nombre y descripción
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            AppRoles.getLabel(role.name),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              role.name,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                          if (role.isSystemRole) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'SISTEMA',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        role.description ??
                                            'Sin descripción registrada.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Chips de conteo
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$assignedPerms de $totalPerms permisos',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: roleColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${role.userCount} ${role.userCount == 1 ? 'usuario asignado' : 'usuarios asignados'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Módulos con permisos activos
                            if (activeModules.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children:
                                    activeModules.map((mod) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              size: 11,
                                              color: roleColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              mod,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],

                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // Barra de acciones
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!role.isSystemRole)
                                  IconButton(
                                    onPressed: () => _confirmDeleteRole(role),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    tooltip: 'Eliminar rol',
                                  ),
                                TextButton.icon(
                                  onPressed: () => _openEditRoleDialog(role),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Editar'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed:
                                      () => _openPermissionsDialog(role, state),
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Configurar Permisos'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: roleColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
