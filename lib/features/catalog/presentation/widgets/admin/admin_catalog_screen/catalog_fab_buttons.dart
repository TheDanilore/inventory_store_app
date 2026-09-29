import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_cart_fab.dart';

/// Botón flotante para agregar producto con estilo Apple HIG / Linear.
class CatalogAddProductFab extends StatelessWidget {
  final VoidCallback onTap;
  const CatalogAddProductFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Agregar producto (N)',
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

/// Dock flotante integrado para entorno Móvil (Smart Action Capsule).
/// Muestra permanentemente el acceso a Caja POS (adaptándose dinámicamente si hay productos)
/// y el botón de crear producto en la zona cómoda del pulgar.
class CatalogMobileActionDock extends StatelessWidget {
  final VoidCallback onAddProduct;
  final Widget? customCartFab;

  const CatalogMobileActionDock({
    super.key,
    required this.onAddProduct,
    this.customCartFab,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        customCartFab ?? const PosCartFab(),
        const SizedBox(height: 12),
        CatalogAddProductFab(onTap: onAddProduct),
      ],
    );
  }
}
