import 'package:flutter/material.dart';

/// Acción por lote para la barra flotante de seleccionados.
class AdminBulkAction<T> {
  final String label;
  final IconData icon;
  final void Function(List<T> selectedItems) onPressed;
  final bool isDestructive;
  final Color? customColor;

  const AdminBulkAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.customColor,
  });
}

