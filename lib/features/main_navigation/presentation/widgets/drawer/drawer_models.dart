import 'package:flutter/material.dart';

/// Modelo de datos para los ítems principales del Drawer.
class DrawerItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<DrawerSubItem> children;
  final String routePath;

  const DrawerItem({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
    this.children = const [],
    required this.routePath,
  });
}

/// Modelo de datos para los sub-ítems anidados del Drawer.
class DrawerSubItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final String routePath;

  const DrawerSubItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    required this.routePath,
  });
}

/// Memoria de sesión estática para retener la posición de scroll
/// y los grupos expandidos del Drawer móvil a través de navegaciones.
class DrawerNavigationMemory {
  DrawerNavigationMemory._();

  static double scrollOffset = 0.0;
  static final Set<String> expandedGroups = <String>{};

  /// Limpia la memoria de navegación al cerrar sesión para evitar filtración entre perfiles.
  static void reset() {
    scrollOffset = 0.0;
    expandedGroups.clear();
  }
}
