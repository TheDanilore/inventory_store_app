import 'package:flutter/material.dart';

/// Utilidad arquitectónica para modales camaleónicos que alternan
/// entre BottomSheet en Móvil (<650) y Dialog centrado en Tablet/Desktop (>=650).
class CatalogAdaptiveModal {
  CatalogAdaptiveModal._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context, bool isMobile) builder,
    double maxWidth = 540,
    bool isDismissible = true,
    Color? barrierColor,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 650;

    if (isMobile) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: isDismissible,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(child: builder(ctx, true)),
            ],
          ),
        ),
      );
    }

    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: builder(ctx, false),
        ),
      ),
    );
  }
}
