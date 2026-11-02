import 'package:flutter/material.dart';

/// Definición declarativa de una columna para [AdminProTable].
class AdminTableColumn<T> {
  final String id;
  final String label;
  final int flex;
  final double? fixedWidth;
  final AlignmentGeometry alignment;
  final bool isSortable;
  final bool isPriorityOnTablet;
  final Widget Function(BuildContext context, T item) cellBuilder;
  final Widget? headerWidget;
  final String? tooltip;

  const AdminTableColumn({
    required this.id,
    required this.label,
    this.flex = 1,
    this.fixedWidth,
    this.alignment = Alignment.centerLeft,
    this.isSortable = false,
    this.isPriorityOnTablet = true,
    required this.cellBuilder,
    this.headerWidget,
    this.tooltip,
  });
}

