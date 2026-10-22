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
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<RolesCubit>().loadRolesAndPermissions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        if (state.isLoading || state.status == RolesStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        final isDesktop = MediaQuery.of(context).size.width >= 768;
        final totalPerms = state.allPermissions.length;
        final totalUsersAssigned = state.roles.fold<int>(
          0,
          (sum, r) => sum + r.userCount,
        );

        final filteredRoles =
            state.roles.where((r) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return r.name.toLowerCase().contains(q) ||
                  AppRoles.getLabel(r.name).toLowerCase().contains(q) ||
                  (r.description?.toLowerCase().contains(q) ?? false);
            }).toList();

        return RefreshIndicator(
          onRefresh: () => context.read<RolesCubit>().loadRolesAndPermissions(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 16,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cabecera de la sección ──────────────────────────────────
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Roles y Permisos del Sistema',
                            style: TextStyle(
                              fontSize: 20,
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
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Roles y Permisos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _openCreateRoleDialog,
                            icon: const Icon(
                              Icons.add_moderator_rounded,
                              size: 16,
                            ),
                            label: const Text('Nuevo Rol'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Control de acceso y capacidades operativas por perfil.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // ── KPI Metrics Bar ─────────────────────────────────────────
                _buildMetricsBar(
                  totalRoles: state.roles.length,
                  totalPerms: totalPerms,
                  totalUsers: totalUsersAssigned,
                  isDesktop: isDesktop,
                ),

                const SizedBox(height: 16),

                // ── Buscador de roles ───────────────────────────────────────
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar rol por nombre, identificador o descripción...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon:
                          _searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                              : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Lista de Roles ──────────────────────────────────────────
                if (filteredRoles.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No hay roles configurados.'
                                : 'No se encontraron roles coincidentes con "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredRoles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final role = filteredRoles[index];
                      return _buildRoleCard(
                        context,
                        role,
                        state,
                        isDesktop: isDesktop,
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

  Widget _buildMetricsBar({
    required int totalRoles,
    required int totalPerms,
    required int totalUsers,
    required bool isDesktop,
  }) {
    final items = [
      _MetricItem(
        icon: Icons.shield_rounded,
        color: Colors.indigo,
        value: '$totalRoles',
        label: 'Roles Configurados',
      ),
      _MetricItem(
        icon: Icons.vpn_key_rounded,
        color: AppColors.teal,
        value: '$totalPerms',
        label: 'Permisos del Sistema',
      ),
      _MetricItem(
        icon: Icons.people_alt_rounded,
        color: Colors.purple.shade600,
        value: '$totalUsers',
        label: 'Usuarios con Rol',
      ),
    ];

    if (!isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _buildMetricCard(items[i], isCompact: true)),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: _buildMetricCard(items[i], isCompact: false)),
        ],
      ],
    );
  }

  Widget _buildMetricCard(_MetricItem item, {required bool isCompact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 16,
        vertical: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 6 : 8),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: isCompact ? 16 : 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: isCompact ? 14 : 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 11.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    RoleWithPermissions role,
    RolesState state, {
    required bool isDesktop,
  }) {
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
      padding: EdgeInsets.all(isDesktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera de la tarjeta (anti-colisión móvil) ───────────────────
          if (!isDesktop) ...[
            // MÓVIL: Estructura vertical limpia sin superposición
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(roleIcon, color: roleColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppRoles.getLabel(role.name),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              role.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (role.isSystemRole)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'SISTEMA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Fila de conteos / estado en móvil
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$assignedPerms de $totalPerms permisos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
                Text(
                  '${role.userCount} ${role.userCount == 1 ? 'usuario asignado' : 'usuarios asignados'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (role.description != null && role.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                role.description!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ] else ...[
            // DESKTOP: Layout horizontal amplio y refinado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(roleIcon, color: roleColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            AppRoles.getLabel(role.name),
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              role.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (role.isSystemRole)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
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
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role.description ?? 'Sin descripción registrada.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
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
          ],

          // ── Módulos con permisos activos ──────────────────────────────────
          if (activeModules.isNotEmpty) ...[
            const SizedBox(height: 12),
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
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
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

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Barra de acciones adaptativa ──────────────────────────────────
          if (!isDesktop)
            Row(
              children: [
                if (!role.isSystemRole) ...[
                  IconButton(
                    onPressed: () => _confirmDeleteRole(role),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Eliminar rol',
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditRoleDialog(role),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _openPermissionsDialog(role, state),
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    label: const Text('Permisos'),
                    style: FilledButton.styleFrom(
                      backgroundColor: roleColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
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
                OutlinedButton.icon(
                  onPressed: () => _openEditRoleDialog(role),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade800,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _openPermissionsDialog(role, state),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Configurar Permisos'),
                  style: FilledButton.styleFrom(
                    backgroundColor: roleColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
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
  }
}

class _MetricItem {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _MetricItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
}
