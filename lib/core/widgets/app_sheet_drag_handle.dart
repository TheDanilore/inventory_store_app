import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Barra de arrastre estándar (drag handle / pill) para todos los Bottom Sheets de la aplicación.
///
/// Sigue las especificaciones Apple HIG / Linear Design System:
/// - Ancho: 36 dp
/// - Alto: 4 dp con esquinas redondeadas
/// - Color adaptativo a modo claro (Slate 300 / Border) y modo oscuro (Slate 600 / DarkBorderSubtle)
/// - Padding superior e inferior óptimo para toque y visualización
class AppSheetDragHandle extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final double width;
  final double height;
  final Color? color;

  const AppSheetDragHandle({
    super.key,
    this.padding = const EdgeInsets.only(top: 8, bottom: 6),
    this.width = 36,
    this.height = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final handleColor =
        color ??
        (isDark ? AppColors.darkBorderSubtle : const Color(0xFFCBD5E1));

    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}
