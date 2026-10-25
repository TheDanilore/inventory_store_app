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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isActive
            ? (isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.45)
                : AppColors.successLight.withValues(alpha: 0.7))
            : (isDark
                ? const Color(0xFF1E293B)
                : AppColors.slateLight.withValues(alpha: 0.5));
    final textColor =
        isActive
            ? (isDark ? const Color(0xFF34D399) : AppColors.successDark)
            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary);
    final dotColor =
        isActive
            ? (isDark ? const Color(0xFF10B981) : AppColors.success)
            : (isDark ? AppColors.darkTextMuted : AppColors.textMuted);
    final borderColor =
        isActive
            ? (isDark
                ? const Color(0xFF059669).withValues(alpha: 0.4)
                : AppColors.success.withValues(alpha: 0.3))
            : (isDark ? AppColors.darkBorder : AppColors.border);

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
              border: Border.all(color: borderColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;

    final Color bgColor;
    final Color textColor;
    final Color borderColor;
    final IconData iconData;
    final String text;

    if (isOut) {
      bgColor =
          isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
              : AppColors.danger.withValues(alpha: 0.08);
      textColor = isDark ? const Color(0xFFF87171) : AppColors.danger;
      borderColor =
          isDark
              ? const Color(0xFFDC2626).withValues(alpha: 0.4)
              : AppColors.danger.withValues(alpha: 0.25);
      iconData = Icons.highlight_off_rounded;
      text = 'Agotado';
    } else if (isLow) {
      bgColor =
          isDark
              ? const Color(0xFF78350F).withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.1);
      textColor = isDark ? const Color(0xFFFBBF24) : AppColors.warningDark;
      borderColor =
          isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.4)
              : AppColors.warning.withValues(alpha: 0.3);
      iconData = Icons.warning_amber_rounded;
      text = 'Bajo ($stock)';
    } else {
      bgColor =
          isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.3)
              : AppColors.teal.withValues(alpha: 0.1);
      textColor = isDark ? const Color(0xFF34D399) : AppColors.tealDark;
      borderColor =
          isDark
              ? const Color(0xFF059669).withValues(alpha: 0.4)
              : AppColors.teal.withValues(alpha: 0.25);
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

/// Badge del tipo de producto (Físico, Digital, Medicamento, etc.).
class ProductTypeBadge extends StatelessWidget {
  final String type;

  const ProductTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final lower = type.toLowerCase();
    final isGood = lower == 'good' || lower == 'fisico' || lower == 'físico';
    final isService = lower == 'servicio' || lower == 'digital';
    final isMedicine = lower == 'medicamento';

    final String label;
    final IconData icon;
    final Color textColor;
    final Color bgColor;

    if (isGood) {
      label = 'Físico';
      icon = Icons.inventory_2_outlined;
      textColor = AppColors.slate;
      bgColor = AppColors.slateLight.withValues(alpha: 0.55);
    } else if (isService) {
      label = 'Digital';
      icon = Icons.cloud_outlined;
      textColor = const Color(0xFF7C3AED);
      bgColor = const Color(0xFFEDE9FE);
    } else if (isMedicine) {
      label = 'Medicamento';
      icon = Icons.medication_outlined;
      textColor = const Color(0xFF0284C7);
      bgColor = const Color(0xFFE0F2FE);
    } else {
      label = type;
      icon = Icons.category_outlined;
      textColor = AppColors.slate;
      bgColor = AppColors.slateLight.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
