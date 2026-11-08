import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/permissions_dialog/role_permission_gateway_banner.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/permissions_dialog/role_permission_module_card.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/permissions_dialog/role_permissions_footer.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/permissions_dialog/role_permissions_header.dart';
import 'package:inventory_store_app/features/roles/presentation/widgets/permissions_dialog/role_permissions_search_bar.dart';

class RolePermissionsDialog extends StatefulWidget {
  final RoleWithPermissions role;
  final List<PermissionEntity> allPermissions;
  final Future<bool> Function(List<String> permissionCodes) onSave;

  const RolePermissionsDialog({
    super.key,
    required this.role,
    required this.allPermissions,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required RoleWithPermissions role,
    required List<PermissionEntity> allPermissions,
    required Future<bool> Function(List<String> permissionCodes) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => RolePermissionsDialog(
            role: role,
            allPermissions: allPermissions,
            onSave: onSave,
          ),
    );
  }

  @override
  State<RolePermissionsDialog> createState() => _RolePermissionsDialogState();
}

class _RolePermissionsDialogState extends State<RolePermissionsDialog> {
  late final Set<String> _selectedPermissions;
  bool _isSaving = false;
  String _searchQuery = '';
  late Map<String, List<PermissionEntity>> _groupedPermissions;

  @override
  void initState() {
    super.initState();
    _selectedPermissions = Set<String>.from(widget.role.permissions);
    _groupedPermissions = _buildGroupedPermissions('');
  }

  bool get _isAdminRole =>
      widget.role.name.toLowerCase() == 'admin' ||
      widget.role.name.toLowerCase() == 'administrador';

  bool get _isCashierRole => widget.role.name.toLowerCase() == 'cashier';

  static const _erpGateway = AppPermissions.erpAccess;
  static const _posGateways = [AppPermissions.posView, AppPermissions.posSale];

  bool get _hasAnyGatewayPermission {
    if (_selectedPermissions.contains(_erpGateway)) return true;
    return _posGateways.any(_selectedPermissions.contains);
  }

  /// Memoización O(N): solo se re-calcula al cambiar el texto de búsqueda
  Map<String, List<PermissionEntity>> _buildGroupedPermissions(String query) {
    final Map<String, List<PermissionEntity>> groups = {};
    final q = query.trim().toLowerCase();

    final filtered = widget.allPermissions.where((p) {
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.code.toLowerCase().contains(q) ||
          p.module.toLowerCase().contains(q);
    });

    for (final perm in filtered) {
      final mod =
          perm.module.isNotEmpty
              ? perm.module
              : AppPermissions.getModule(perm.code);
      groups.putIfAbsent(mod, () => []).add(perm);
    }

    const accessModule = 'Acceso y Seguridad';
    const posModule = 'Punto de Venta (POS)';
    final sortedKeys =
        groups.keys.toList()..sort((a, b) {
          if (a == accessModule) return -1;
          if (b == accessModule) return 1;
          if (a == posModule) return -1;
          if (b == posModule) return 1;
          return a.compareTo(b);
        });

    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, groups[k]!)));
  }

  void _onSearchChanged(String v) {
    final clean = v.trim();
    if (clean != _searchQuery) {
      setState(() {
        _searchQuery = clean;
        _groupedPermissions = _buildGroupedPermissions(clean);
      });
    }
  }

  void _togglePermission(String code) {
    if (_isAdminRole) return;
    setState(() {
      if (_selectedPermissions.contains(code)) {
        _selectedPermissions.remove(code);
        if (code == AppPermissions.posView) {
          _selectedPermissions.removeWhere((p) => p.startsWith('pos.'));
        }
      } else {
        _selectedPermissions.add(code);
        if (code.startsWith('pos.') && code != AppPermissions.posView) {
          _selectedPermissions.add(AppPermissions.posView);
        }
        if (!code.startsWith('pos.') && code != AppPermissions.erpAccess) {
          _selectedPermissions.add(AppPermissions.erpAccess);
        }
      }
    });
  }

  void _toggleModule(List<PermissionEntity> perms, bool selectAll) {
    if (_isAdminRole) return;
    setState(() {
      for (final p in perms) {
        if (selectAll) {
          _selectedPermissions.add(p.code);
          if (p.code.startsWith('pos.')) {
            _selectedPermissions.add(AppPermissions.posView);
          } else if (p.code != AppPermissions.erpAccess) {
            _selectedPermissions.add(AppPermissions.erpAccess);
          }
        } else {
          _selectedPermissions.remove(p.code);
        }
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPermissions.addAll(widget.allPermissions.map((p) => p.code));
    });
  }

  void _deselectAll() {
    setState(() => _selectedPermissions.clear());
  }

  Future<void> _handleSave() async {
    if (!_isAdminRole && !_hasAnyGatewayPermission) {
      final proceed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin acceso a ningún entorno',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Este rol no tiene asignado acceso al ERP (erp.access) ni al '
                'Punto de Venta (pos.view / pos.sale).\n\n'
                'Los usuarios con este rol no tendrán un destino válido al '
                'iniciar sesión.\n\n'
                '¿Deseas guardar igual?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Volver y corregir'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Guardar igual'),
                ),
              ],
            ),
      );
      if (!(proceed ?? false)) return;
    }

    setState(() => _isSaving = true);
    final success = await widget.onSave(_selectedPermissions.toList());
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 40 : 12,
        vertical: isDesktop ? 24 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight:
              MediaQuery.of(context).size.height * (isDesktop ? 0.88 : 0.94),
        ),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RolePermissionsHeader(
                role: widget.role,
                activePermissionsCount: _selectedPermissions.length,
                isDesktop: isDesktop,
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 14),

              if (_isAdminRole) const RoleAdminBanner(),
              if (_isCashierRole) const RoleCashierBanner(),

              RolePermissionsSearchBar(
                isDesktop: isDesktop,
                totalCount: widget.allPermissions.length,
                selectedPermissions: _selectedPermissions,
                isAdminRole: _isAdminRole,
                onSearchChanged: _onSearchChanged,
                onSelectAll: _selectAll,
                onDeselectAll: _deselectAll,
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              // Lista de Módulos con Scroll optimizado
              Expanded(
                child:
                    _groupedPermissions.isEmpty
                        ? Center(
                          child: Text(
                            'No se encontraron permisos para "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: _groupedPermissions.keys.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final module = _groupedPermissions.keys.elementAt(
                              index,
                            );
                            final perms = _groupedPermissions[module]!;
                            final allSelected = perms.every(
                              (p) => _selectedPermissions.contains(p.code),
                            );

                            return RolePermissionModuleCard(
                              module: module,
                              permissions: perms,
                              selectedPermissions: _selectedPermissions,
                              onToggleModule:
                                  () => _toggleModule(perms, !allSelected),
                              onTogglePermission: _togglePermission,
                            );
                          },
                        ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              RolePermissionsFooter(
                isDesktop: isDesktop,
                isSaving: _isSaving,
                isAdminRole: _isAdminRole,
                onCancel: () => Navigator.of(context).pop(),
                onSave: _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
