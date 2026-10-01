import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Utilidad arquitectónica para presentar formularios y paneles de forma adaptativa:
/// - En Desktop / Tablet (ancho >= 768px): Slide-over Right Side Sheet (split emergente de la derecha).
///   Se renderiza por encima de toda la interfaz (`useRootNavigator: true`), con scrim oscuro,
///   desenfoque de fondo y animación de deslizamiento lateral de 0 a 1.
/// - En Móvil (ancho < 768px): Modal Bottom Sheet con esquinas redondeadas y soporte de gestos táctiles.
class AdaptiveSideSheet {
  AdaptiveSideSheet._();

  static const double breakpoint = 768.0;
  static const double defaultDesktopWidth = 490.0;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context, bool isSlideOver) builder,
    double desktopWidth = defaultDesktopWidth,
    bool barrierDismissible = true,
    String barrierLabel = 'Cerrar',
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSlideOver = screenWidth >= breakpoint;

    if (isSlideOver) {
      final width = screenWidth < (desktopWidth + 40)
          ? screenWidth * 0.92
          : desktopWidth;

      return showGeneralDialog<T>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel,
        barrierColor: Colors.black.withValues(alpha: 0.38),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (dialogCtx, anim1, anim2) {
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: const SizedBox.expand(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  elevation: 16,
                  child: Container(
                    width: width,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(dialogCtx).scaffoldBackgroundColor,
                      border: const Border(
                        left: BorderSide(color: AppColors.border, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 36,
                          offset: const Offset(-8, 0),
                        ),
                      ],
                    ),
                    child: builder(dialogCtx, true),
                  ),
                ),
              ),
            ],
          );
        },
        transitionBuilder: (context, anim1, anim2, child) {
          final curved = CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => builder(sheetCtx, false),
      );
    }
  }
}
