import 'package:flutter/material.dart';

/// Utilidades compartidas para filtrar acciones redundantes en barras de navegación.
class TopBarActionUtils {
  const TopBarActionUtils._();

  /// Identifica botones de refresco que no deben duplicarse en las barras globales.
  static bool isRefreshWidget(Widget widget) {
    if (widget is IconButton) {
      final icon = widget.icon;
      if (icon is Icon &&
          (icon.icon == Icons.refresh_rounded || icon.icon == Icons.refresh)) {
        return true;
      }
      final tooltip = widget.tooltip?.toLowerCase() ?? '';
      if (tooltip.contains('actualizar') ||
          tooltip.contains('refrescar') ||
          tooltip.contains('recargar')) {
        return true;
      }
    }
    return false;
  }

  /// Filtra la lista en una sola pasada evitando iteraciones redundantes en `build()`.
  static List<Widget> filterVisibleActions(List<Widget>? actions) {
    if (actions == null || actions.isEmpty) return const [];
    final visible = <Widget>[];
    for (final action in actions) {
      if (!isRefreshWidget(action)) {
        visible.add(action);
      }
    }
    return visible;
  }
}
