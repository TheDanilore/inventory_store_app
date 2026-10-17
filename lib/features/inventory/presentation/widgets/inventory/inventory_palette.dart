import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Colores semánticos del módulo de Inventario con soporte claro/oscuro.
///
/// Uso: `InventoryPalette.of(context).surface`.
/// Reemplaza los `AppColors.surface` / `Color(0xFF...)` fijos que hacían que
/// Stock y Lotes se vieran en modo claro aunque el resto de la pantalla
/// estuviera en oscuro.
class InventoryPalette {
  final bool isDark;
  const InventoryPalette._(this.isDark);

  factory InventoryPalette.of(BuildContext context) =>
      InventoryPalette._(Theme.of(context).brightness == Brightness.dark);

  // Superficies y bordes
  Color get surface => isDark ? AppColors.darkSurface : AppColors.surface;
  Color get background =>
      isDark ? AppColors.darkBackground : AppColors.background;
  Color get border => isDark ? AppColors.darkBorder : AppColors.border;
  Color get borderStrong =>
      isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1);
  Color get subtle =>
      isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9);
  Color get selectedTint =>
      isDark
          ? AppColors.teal.withValues(alpha: 0.14)
          : const Color(0xFFF0FDFA);

  // Texto
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get textMuted => isDark ? AppColors.darkTextMuted : AppColors.textMuted;

  // Estados: crítico / atención / correcto (fondo, borde, texto)
  Color get dangerBg =>
      isDark ? AppColors.danger.withValues(alpha: 0.16) : const Color(0xFFFEE2E2);
  Color get dangerBd =>
      isDark ? AppColors.danger.withValues(alpha: 0.45) : const Color(0xFFFCA5A5);
  Color get dangerFg => isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);

  Color get warnBg =>
      isDark ? AppColors.warning.withValues(alpha: 0.16) : const Color(0xFFFEF3C7);
  Color get warnBd =>
      isDark ? AppColors.warning.withValues(alpha: 0.45) : const Color(0xFFFCD34D);
  Color get warnFg => isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);

  Color get okBg =>
      isDark ? AppColors.success.withValues(alpha: 0.16) : const Color(0xFFDCFCE7);
  Color get okBd =>
      isDark ? AppColors.success.withValues(alpha: 0.45) : const Color(0xFF86EFAC);
  Color get okFg => isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534);
}
