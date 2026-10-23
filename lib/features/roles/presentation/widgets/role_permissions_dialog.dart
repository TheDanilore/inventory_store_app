import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
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

    // Orden: "Acceso y Seguridad" primero → "Punto de Venta (POS)" segundo → resto alfabético.
    // Esto garantiza que los permisos de puerta de entrada sean siempre visibles arriba.
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

  bool get _isAdminRole =>
      widget.role.name.toLowerCase() == 'admin' ||
      widget.role.name.toLowerCase() == 'administrador';

  bool get _isCashierRole => widget.role.name.toLowerCase() == 'cashier';

  /// Permisos de puerta de entrada: definen en qué entorno opera el usuario.
  /// Al menos uno de los dos grupos debe estar activo para que el rol sea útil.
  static const _erpGateway = AppPermissions.erpAccess;
  static const _posGateways = [AppPermissions.posView, AppPermissions.posSale];

  /// Devuelve true si el código corresponde a un permiso de puerta de entrada
  /// (erp.access o pos.view) que merece tratamiento visual especial.
  bool _isGatewayPermission(String code) =>
      code == AppPermissions.erpAccess || code == AppPermissions.posView;

  /// Verdadero si el rol tiene configurado acceso a al menos un entorno.
  bool get _hasAnyGatewayPermission {
    if (_selectedPermissions.contains(_erpGateway)) return true;
    return _posGateways.any(_selectedPermissions.contains);
  }

  void _togglePermission(String code) {
    if (_isAdminRole) return;
    setState(() {
      if (_selectedPermissions.contains(code)) {
        _selectedPermissions.remove(code);
        // Si retira la puerta de entrada pos.view, retirar permisos operativos del POS
        if (code == AppPermissions.posView) {
          _selectedPermissions.removeWhere((p) => p.startsWith('pos.'));
        }
      } else {
        _selectedPermissions.add(code);
        // Dependencia inteligente POS: Si activa cualquier función del POS, auto-activar pos.view
        if (code.startsWith('pos.') && code != AppPermissions.posView) {
          _selectedPermissions.add(AppPermissions.posView);
        }
        // Dependencia inteligente ERP: Si activa cualquier módulo operativo del ERP, auto-activar erp.access
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

  Future<void> _handleSave() async {
    // Validación: el rol debe tener acceso al menos a un entorno (ERP o POS).
    // Un rol sin erp.access ni pos.view/pos.sale deja al usuario "flotando" al login.
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
    final groups = _groupedPermissions;
    final roleTitle = AppRoles.getLabel(widget.role.name);

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
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                              'Permisos: $roleTitle',
                              style: TextStyle(
                                fontSize: isDesktop ? 18 : 16,
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
                          maxLines: isDesktop ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_isAdminRole)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: Colors.indigo.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El rol Administrador cuenta con acceso total e inmutable a todos los módulos y permisos del sistema.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isCashierRole)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.point_of_sale_rounded,
                        color: Colors.teal.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rol de Punto de Venta exclusivo',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.teal.shade900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'El cajero accede directamente al POS al iniciar sesi\u00f3n y no puede ingresar al ERP.\n'
                              '\u26a0\ufe0f Si necesitas darle acceso al ERP, activa el permiso "erp.access" (Acceso y Seguridad) en esta lista.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.teal.shade800,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Buscador y acciones masivas ────────────────────────────────
              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
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
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
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
                      label: const Text('Marcar Todos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _selectedPermissions.clear());
                      },
                      icon: const Icon(Icons.deselect_rounded, size: 16),
                      label: const Text('Desmarcar Todos'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 38,
                      child: TextField(
                        onChanged:
                            (v) => setState(() => _searchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Buscar permiso...',
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedPermissions.length} de ${widget.allPermissions.length} seleccionados',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedPermissions.addAll(
                                    widget.allPermissions.map((p) => p.code),
                                  );
                                });
                              },
                              icon: const Icon(
                                Icons.select_all_rounded,
                                size: 14,
                              ),
                              label: const Text('Todos'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _selectedPermissions.clear());
                              },
                              icon: const Icon(
                                Icons.deselect_rounded,
                                size: 14,
                              ),
                              label: const Text('Limpiar'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: Colors.grey.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildEnvironmentStatusBanner(),
                  ],
                ),
              const SizedBox(height: 12),
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
                        : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: groups.keys.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final module = groups.keys.elementAt(index);
                            final perms = groups[module]!;
                            final allSelected = perms.every(
                              (p) => _selectedPermissions.contains(p.code),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                          onPressed:
                                              () => _toggleModule(
                                                perms,
                                                !allSelected,
                                              ),
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            foregroundColor:
                                                allSelected
                                                    ? Colors.grey.shade700
                                                    : AppColors.primary,
                                            textStyle: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          child: Text(
                                            allSelected
                                                ? 'Desmarcar grupo'
                                                : 'Marcar grupo',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),

                                  // Lista de permisos de este módulo
                                  for (final p in perms)
                                    _buildPermissionTile(p),
                                ],
                              ),
                            );
                          },
                        ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── Botones de Guardado adaptativos ─────────────────────────────
              if (!isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed:
                            (_isSaving || _isAdminRole) ? null : _handleSave,
                        icon:
                            _isSaving
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Icon(
                                  _isAdminRole
                                      ? Icons.shield_rounded
                                      : Icons.check_rounded,
                                  size: 16,
                                ),
                        label: Text(
                          _isSaving
                              ? 'Guardando...'
                              : (_isAdminRole
                                  ? 'Acceso Total Fijo'
                                  : 'Guardar Permisos'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 11),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed:
                          (_isSaving || _isAdminRole) ? null : _handleSave,
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
                              : Icon(
                                _isAdminRole
                                    ? Icons.shield_rounded
                                    : Icons.check_rounded,
                                size: 18,
                              ),
                      label: Text(
                        _isSaving
                            ? 'Guardando...'
                            : (_isAdminRole
                                ? 'Acceso Total Fijo'
                                : 'Guardar Permisos'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
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
        ),
      ),
    );
  }

  /// Construye el tile de un permiso.
  /// Los permisos de puerta de entrada (erp.access y pos.view) reciben un
  /// fondo de color suave y un chip identificador para que sean fáciles de ubicar.
  Widget _buildPermissionTile(PermissionEntity p) {
    final isGateway = _isGatewayPermission(p.code);
    final isErp = p.code == AppPermissions.erpAccess;
    final isPos = p.code == AppPermissions.posView;

    final gatewayBg =
        isErp
            ? Colors.indigo.shade50
            : isPos
            ? Colors.teal.shade50
            : null;

    final gatewayBorder =
        isErp
            ? Colors.indigo.shade100
            : isPos
            ? Colors.teal.shade100
            : null;

    final chipColor = isErp ? Colors.indigo.shade700 : Colors.teal.shade700;

    final chipLabel = isErp ? 'Acceso ERP' : 'Acceso POS';

    Widget tile = CheckboxListTile(
      value: _selectedPermissions.contains(p.code),
      activeColor: isErp ? Colors.indigo.shade600 : AppColors.primary,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      onChanged: (_) => _togglePermission(p.code),
      title: Row(
        children: [
          Flexible(
            child: Text(
              p.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isGateway ? Colors.black87 : Colors.black87,
              ),
            ),
          ),
          if (isGateway) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: chipColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                chipLabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: chipColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        p.code,
        style: TextStyle(
          fontSize: 10.5,
          fontFamily: 'monospace',
          color:
              isGateway
                  ? chipColor.withValues(alpha: 0.7)
                  : Colors.grey.shade500,
        ),
      ),
    );

    if (!isGateway) return tile;

    // Envuelve en contenedor coloreado
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: gatewayBg,
        border: Border(
          left: BorderSide(
            color: gatewayBorder ?? Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: tile,
    );
  }

  /// Banner visual que muestra en tiempo real a qué entornos tiene acceso este rol
  /// y si el POS está en modo operativo completo o solo consulta.
  Widget _buildEnvironmentStatusBanner() {
    if (_isAdminRole) return const SizedBox.shrink();

    final hasErp = _selectedPermissions.contains(AppPermissions.erpAccess);
    final hasPos = _selectedPermissions.contains(AppPermissions.posView);
    final hasPosSale = _selectedPermissions.contains(AppPermissions.posSale);

    if (!hasErp && !hasPos) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Colors.amber.shade800,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sin entorno asignado: Habilite Acceso ERP o Acceso POS para que el rol pueda ingresar.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(
            'Entornos:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 8),
          if (hasErp)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_rounded,
                    size: 12,
                    color: Colors.indigo.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ERP Administrativo',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ],
              ),
            ),
          if (hasErp && hasPos) const SizedBox(width: 6),
          if (hasPos)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.point_of_sale_rounded,
                    size: 12,
                    color: Colors.teal.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasPosSale ? 'POS (Cobro activo)' : 'POS (Solo consulta)',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
