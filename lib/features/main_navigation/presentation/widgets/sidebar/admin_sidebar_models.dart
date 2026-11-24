import 'package:flutter/material.dart';

/// Modelo de datos que describe un ítem o grupo del menú de navegación.
class AdminSidebarItem {
  final IconData icon;
  final String title;
  final String routePath;
  final Widget? trailing;
  final List<AdminSidebarItem> children;

  const AdminSidebarItem({
    required this.icon,
    required this.title,
    required this.routePath,
    this.trailing,
    this.children = const [],
  });
}

/// Memoria estática de navegación para retener la posición exacta de scroll
/// y los grupos expandidos a través de transiciones de ruta en el ERP.
class SidebarNavigationMemory {
  SidebarNavigationMemory._();

  static double scrollOffset = 0.0;
  static final Set<String> expandedGroups = <String>{};

  /// Limpia el estado en memoria al cerrar sesión para evitar filtración entre cuentas.
  static void reset() {
    scrollOffset = 0.0;
    expandedGroups.clear();
  }
}
