import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Botón circular flotante estilizado para interacción con el mapa.
class CustomerMapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;

  const CustomerMapIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Controles flotantes laterales de navegación para el mapa (Zoom in, Zoom out, GPS, Ajuste de límites).
class CustomerMapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocateMe;
  final bool isLocating;
  final VoidCallback? onFitAll;
  final bool showFitAll;
  final double bottomPosition;

  const CustomerMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocateMe,
    required this.isLocating,
    this.onFitAll,
    this.showFitAll = false,
    required this.bottomPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: bottomPosition,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomerMapIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Acercar (+)',
            onTap: onZoomIn,
          ),
          const SizedBox(height: 8),
          CustomerMapIconButton(
            icon: Icons.remove_rounded,
            tooltip: 'Alejar (-)',
            onTap: onZoomOut,
          ),
          const SizedBox(height: 12),
          CustomerMapIconButton(
            icon:
                isLocating
                    ? Icons.hourglass_top_rounded
                    : Icons.my_location_rounded,
            tooltip: 'Mi ubicación GPS',
            iconColor: AppColors.teal,
            onTap: onLocateMe,
          ),
          if (showFitAll && onFitAll != null) ...[
            const SizedBox(height: 8),
            CustomerMapIconButton(
              icon: Icons.fullscreen_rounded,
              tooltip: 'Ver todas las ubicaciones',
              iconColor: AppColors.primary,
              onTap: onFitAll!,
            ),
          ],
        ],
      ),
    );
  }
}
