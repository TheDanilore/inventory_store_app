import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class UserFormRoleInfo {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const UserFormRoleInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  static List<UserFormRoleInfo> get allRoles => [
    const UserFormRoleInfo(
      id: AppRoles.admin,
      title: 'Admin',
      subtitle: 'Acceso total al sistema',
      icon: Icons.admin_panel_settings_outlined,
      color: Colors.indigo,
    ),
    const UserFormRoleInfo(
      id: AppRoles.cashier,
      title: 'Cajero',
      subtitle: 'Punto de venta y ventas',
      icon: Icons.point_of_sale_rounded,
      color: AppColors.teal,
    ),
    UserFormRoleInfo(
      id: AppRoles.warehouseKeeper,
      title: 'Almacén',
      subtitle: 'Inventario y kardex',
      icon: Icons.inventory_2_outlined,
      color: Colors.purple.shade600,
    ),
    UserFormRoleInfo(
      id: AppRoles.employee,
      title: 'Empleado',
      subtitle: 'Operaciones generales',
      icon: Icons.badge_outlined,
      color: Colors.orange.shade700,
    ),
  ];
}
