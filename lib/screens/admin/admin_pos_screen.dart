import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/screens/admin/admin_desktop_pos_screen.dart';
import 'package:inventory_store_app/providers/pos_provider.dart';

// ─── Breakpoint a partir del cual se activa el layout dividido ───────────────
const double _kSplitBreakpoint = 900;

/// Pantalla unificada POS.
///
/// **< 900 px (móvil / tablet angosta):** comportamiento original — el catálogo
/// muestra el botón flotante de carrito y navega al checkout por separado.
///
/// **≥ 900 px (tablet ancha / desktop):** layout dividido lado a lado:
/// - Izquierda: catálogo con búsqueda, filtros y grid de productos.
/// - Derecha: panel de checkout fijo (sin scroll de página, solo el panel
///   tiene scroll interno).
///
/// Ambos paneles leen y escriben el mismo [PosProvider] que ya existía,
/// por lo que no se necesita ningún cambio en la lógica de negocio.
class AdminPosScreen extends StatelessWidget {
  const AdminPosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kSplitBreakpoint) {
          return const AdminDesktopPosScreen();
        }
        // En móvil simplemente mostramos el catálogo; el checkout se alcanza
        // a través del botón flotante de carrito que ya existe.
        return const AdminCatalogScreen();
      },
    );
  }
}
