import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Píldora de estado Activo/Inactivo con soporte para micro-interacción y tooltip.
class ProductStatusPill extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final bool isDense;

  const ProductStatusPill({
    super.key,
    required this.isActive,
    required this.onTap,
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isActive
            ? AppColors.successLight.withValues(alpha: 0.7)
            : AppColors.slateLight.withValues(alpha: 0.5);
    final textColor =
        isActive ? AppColors.successDark : AppColors.textSecondary;
    final dotColor = isActive ? AppColors.success : AppColors.textMuted;

    return Tooltip(
      message: isActive ? 'Clic para desactivar' : 'Clic para activar',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isDense ? 8 : 10,
              vertical: isDense ? 3 : 4.5,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isActive
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontSize: isDense ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge de stock semántico accesible WCAG AAA con micro-icono y bordes definidos.
class ProductStockBadge extends StatelessWidget {
  final int stock;

  const ProductStockBadge({super.key, required this.stock});

  @override
  Widget build(BuildContext context) {
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;

    final Color bgColor;
    final Color textColor;
    final Color borderColor;
    final IconData iconData;
    final String text;

    if (isOut) {
      bgColor = AppColors.danger.withValues(alpha: 0.08);
      textColor = AppColors.danger;
      borderColor = AppColors.danger.withValues(alpha: 0.25);
      iconData = Icons.highlight_off_rounded;
      text = 'Agotado';
    } else if (isLow) {
      bgColor = AppColors.warning.withValues(alpha: 0.1);
      textColor = AppColors.warningDark;
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      iconData = Icons.warning_amber_rounded;
      text = 'Bajo ($stock)';
    } else {
      bgColor = AppColors.teal.withValues(alpha: 0.1);
      textColor = AppColors.tealDark;
      borderColor = AppColors.teal.withValues(alpha: 0.25);
      iconData = Icons.check_circle_outline_rounded;
      text = '$stock unid.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge del tipo de producto (Medicamento, Servicio, Estándar, etc.).
class ProductTypeBadge extends StatelessWidget {
  final String type;

  const ProductTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isMedicine = type.toLowerCase() == 'medicamento';
    final isService = type.toLowerCase() == 'servicio';

    final Color textColor;
    final Color bgColor;

    if (isMedicine) {
      textColor = const Color(0xFF0284C7);
      bgColor = const Color(0xFFE0F2FE);
    } else if (isService) {
      textColor = const Color(0xFF7C3AED);
      bgColor = const Color(0xFFEDE9FE);
    } else {
      textColor = AppColors.slate;
      bgColor = AppColors.slateLight.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Chip segmentado de filtro con soporte para iconos e interactividad animada.
class ProductSegmentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  const ProductSegmentChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color:
                    isSelected
                        ? Colors.white
                        : (iconColor ?? AppColors.textSecondary),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
