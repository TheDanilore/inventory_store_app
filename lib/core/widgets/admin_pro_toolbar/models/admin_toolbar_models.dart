import 'package:flutter/material.dart';

/// Configuración para la acción principal del toolbar (CTA).
/// El atajo de teclado [keyHint] se muestra exclusivamente en el Tooltip.
class AdminProToolbarAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? keyHint;
  final bool isHighlighted;
  final Color? highlightColor;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AdminProToolbarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.keyHint = 'N',
    this.isHighlighted = false,
    this.highlightColor,
    this.backgroundColor,
    this.foregroundColor,
  });
}

/// Configuración para alternar vistas (Tabla vs Tarjetas / Grid).
class AdminProViewToggleConfig {
  final bool isTableView;
  final ValueChanged<bool> onToggleTableView;
  final String tableTooltip;
  final String cardsTooltip;
  final Color? activeColor;
  final IconData tableIcon;
  final IconData cardsIcon;
  final bool showOnMobile;
  final bool showOnTablet;

  const AdminProViewToggleConfig({
    required this.isTableView,
    required this.onToggleTableView,
    this.tableTooltip = 'Vista en Tabla',
    this.cardsTooltip = 'Vista en Tarjetas',
    this.activeColor,
    this.tableIcon = Icons.table_rows_rounded,
    this.cardsIcon = Icons.grid_view_rounded,
    this.showOnMobile = false,
    this.showOnTablet = true,
  });
}

/// Opción individual de un grupo de filtros.
class AdminFilterOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;

  const AdminFilterOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });
}

/// Modo de visualización de un grupo de filtros en el modal bottom sheet de móvil.
enum AdminFilterDisplayType {
  /// Si tiene <= 4 opciones se muestra como chips horizontales; si tiene más, como select desplegable.
  auto,

  /// Siempre como chips envueltos (Wrap). Ideal para opciones cortas y rápidas.
  chips,

  /// Siempre como selector desplegable estilizado. Ideal para listas largas.
  select,
}

/// Grupo de filtros descrito como DATOS inmutables (desacoplado de widgets).
class AdminFilterGroup<T> {
  final String title;
  final IconData? icon;
  final List<AdminFilterOption<T>> options;
  final T selected;

  /// Valor que significa "sin filtro" (ej. 'ALL', null). Sirve para el badge
  /// de filtros activos y para el botón "Limpiar".
  final T defaultValue;
  final ValueChanged<T> onSelected;

  /// Modo de presentación en entornos táctiles (Mobile / Sheet).
  final AdminFilterDisplayType displayType;

  const AdminFilterGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.defaultValue,
    required this.onSelected,
    this.icon,
    this.displayType = AdminFilterDisplayType.auto,
  });

  bool get isActive => selected != defaultValue;

  /// Invoca [onSelected] de forma segura evitando problemas de covarianza en Dart.
  void select(dynamic value) {
    onSelected(value as T);
  }

  /// Restablece el filtro al valor por defecto.
  void reset() {
    onSelected(defaultValue);
  }

  /// Comprueba si la opción dada está actualmente seleccionada.
  bool isSelected(dynamic value) => selected == value;

  String get selectedLabel {
    for (final o in options) {
      if (o.value == selected) return o.label;
    }
    return title;
  }
}

/// Instantánea inmutable de filtros para sincronización reactiva con modal sheets.
class FiltersSnapshot {
  final List<AdminFilterGroup<dynamic>> groups;
  final List<Widget> extras;
  final List<Widget> legacyWidgets;
  final String applyLabel;

  const FiltersSnapshot({
    required this.groups,
    required this.extras,
    required this.legacyWidgets,
    required this.applyLabel,
  });
}
