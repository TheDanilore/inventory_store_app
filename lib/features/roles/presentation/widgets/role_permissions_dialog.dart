import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedPermissions = Set<String>.from(widget.role.permissions);
  }

  Map<String, List<PermissionEntity>> get _groupedPermissions {
    final Map<String, List<PermissionEntity>> groups = {};
    final filtered = widget.allPermissions.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
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
    return groups;
  }

  void _togglePermission(String code) {
    setState(() {
      if (_selectedPermissions.contains(code)) {
        _selectedPermissions.remove(code);
      } else {
        _selectedPermissions.add(code);
      }
    });
  }

  void _toggleModule(List<PermissionEntity> perms, bool selectAll) {
    setState(() {
      for (final p in perms) {
        if (selectAll) {
          _selectedPermissions.add(p.code);
        } else {
          _selectedPermissions.remove(p.code);
        }
      }
    });
  }

  Future<void> _handleSave() async {
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
    final groups = _groupedPermissions;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ─────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Permisos del Rol: ${widget.role.name.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_selectedPermissions.length} activos',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.teal,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.role.description ??
                              'Configura las acciones y accesos autorizados para este rol.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Buscador y acciones masivas ────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        onChanged:
                            (v) => setState(() => _searchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Buscar permiso por nombre o código...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedPermissions.addAll(
                          widget.allPermissions.map((p) => p.code),
                        );
                      });
                    },
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: Text(isDesktop ? 'Marcar Todos' : 'Todos'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedPermissions.clear());
                    },
                    icon: const Icon(Icons.deselect_rounded, size: 16),
                    label: Text(isDesktop ? 'Desmarcar Todos' : 'Limpiar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),

              // ── Lista de Módulos y Permisos con Scroll ─────────────────────
              Expanded(
                child:
                    groups.isEmpty
                        ? Center(
                          child: Text(
                            'No se encontraron permisos para "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        )
                        : ListView.builder(
                          itemCount: groups.keys.length,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemBuilder: (context, idx) {
                            final moduleName = groups.keys.elementAt(idx);
                            final modulePerms = groups[moduleName]!;
                            final allModuleSelected = modulePerms.every(
                              (p) => _selectedPermissions.contains(p.code),
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Cabecera del módulo
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(13),
                                      ),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          moduleName.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey.shade700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        InkWell(
                                          onTap:
                                              () => _toggleModule(
                                                modulePerms,
                                                !allModuleSelected,
                                              ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            child: Text(
                                              allModuleSelected
                                                  ? 'Desmarcar grupo'
                                                  : 'Marcar grupo',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Lista de checkboxes de permisos
                                  ...modulePerms.map((perm) {
                                    final isChecked = _selectedPermissions
                                        .contains(perm.code);

                                    return InkWell(
                                      onTap: () => _togglePermission(perm.code),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isChecked,
                                              activeColor: AppColors.primary,
                                              onChanged:
                                                  (_) => _togglePermission(
                                                    perm.code,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    perm.name,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          isChecked
                                                              ? FontWeight.w700
                                                              : FontWeight.w500,
                                                      color:
                                                          isChecked
                                                              ? Colors.black87
                                                              : Colors
                                                                  .grey
                                                                  .shade700,
                                                    ),
                                                  ),
                                                  Text(
                                                    perm.code,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: 'monospace',
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 16),

              // ── Botones de Guardado ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isSaving ? 'Guardando...' : 'Guardar Permisos',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
