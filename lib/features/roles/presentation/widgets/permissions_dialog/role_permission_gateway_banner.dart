import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';

class RoleAdminBanner extends StatelessWidget {
  const RoleAdminBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, color: Colors.indigo.shade700, size: 20),
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
    );
  }
}

class RoleCashierBanner extends StatelessWidget {
  const RoleCashierBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  'El cajero accede directamente al POS al iniciar sesión y no puede ingresar al ERP.\n'
                  '⚠️ Si necesitas darle acceso al ERP, activa el permiso "erp.access" (Acceso y Seguridad) en esta lista.',
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
    );
  }
}

class RoleEnvironmentStatusBanner extends StatelessWidget {
  final Set<String> selectedPermissions;
  final bool isAdminRole;

  const RoleEnvironmentStatusBanner({
    super.key,
    required this.selectedPermissions,
    required this.isAdminRole,
  });

  @override
  Widget build(BuildContext context) {
    if (isAdminRole) return const SizedBox.shrink();

    final hasErp = selectedPermissions.contains(AppPermissions.erpAccess);
    final hasPos = selectedPermissions.contains(AppPermissions.posView);
    final hasPosSale = selectedPermissions.contains(AppPermissions.posSale);

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
