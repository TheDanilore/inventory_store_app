import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

enum SnackbarType { success, error, warning, info }

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.success,
    Color? backgroundColor,
    Duration duration = const Duration(
      seconds: 2,
    ), // Ajustado a 2 segundos como en tu diseño
  }) {
    // Oculta el snackbar actual si hay uno en pantalla para mostrar el nuevo rápido
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Determinamos el color de fondo basado en tu AppColors
    final resolvedBackgroundColor =
        backgroundColor ??
        switch (type) {
          SnackbarType.success => AppColors.success,
          SnackbarType.error =>
            AppColors.accent, // Usando accent como error según tu diseño
          SnackbarType.warning => AppColors.warning,
          SnackbarType.info => AppColors.info,
        };

    // Determinamos el icono
    IconData iconData;
    switch (type) {
      case SnackbarType.success:
        iconData = Icons.check_circle_outline_rounded;
        break;
      case SnackbarType.error:
      case SnackbarType.warning:
        iconData = Icons.warning_amber_rounded;
        break;
      case SnackbarType.info:
        iconData = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(iconData, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: resolvedBackgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }
}
