import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_text.dart';

/// Modelo de datos inmutable para una pestaña del Centro de Ayuda.
class HelpTabModel {
  final String label;
  final IconData icon;
  final List<HelpGroupModel> groups;

  const HelpTabModel({
    required this.label,
    required this.icon,
    required this.groups,
  });
}

/// Agrupación temática dentro de una pestaña.
class HelpGroupModel {
  final String? title;
  final String? subtitle;
  final int columns;
  final List<HelpItemModel> items;

  const HelpGroupModel({
    this.title,
    this.subtitle,
    this.columns = 1,
    required this.items,
  });
}

/// Item indexable con contenido renderizable.
class HelpItemModel {
  final String text; // Texto indexado para el motor de búsqueda
  final Widget child;

  const HelpItemModel(this.text, this.child);
}

/// Coincidencia de búsqueda indexada.
class HelpSearchHit {
  final int tabIndex;
  final HelpGroupModel group;
  final List<HelpItemModel> items;

  const HelpSearchHit({
    required this.tabIndex,
    required this.group,
    required this.items,
  });
}

/// Tokens semánticos de diseño constantes (0 allocations por build) para el Centro de Ayuda.
class HelpThemeTokens {
  final bool isDark;
  final Color bg;
  final Color surface;
  final Color field;
  final Color border;
  final Color strongBorder;
  final Color title;
  final Color body;
  final Color muted;
  final Color accent;
  final Color primaryBtn;

  const HelpThemeTokens({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.field,
    required this.border,
    required this.strongBorder,
    required this.title,
    required this.body,
    required this.muted,
    required this.accent,
    required this.primaryBtn,
  });

  static const HelpThemeTokens light = HelpThemeTokens(
    isDark: false,
    bg: AppColors.background,
    surface: AppColors.surface,
    field: AppColors.surfaceDark,
    border: AppColors.border,
    strongBorder: Color(0xFFCBD5E1),
    title: AppColors.textPrimary,
    body: Color(0xFF334155),
    muted: AppColors.textSecondary,
    accent: Color(0xFF2563EB),
    primaryBtn: Color(0xFF2563EB),
  );

  static const HelpThemeTokens dark = HelpThemeTokens(
    isDark: true,
    bg: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    field: AppColors.darkBackground,
    border: AppColors.darkBorder,
    strongBorder: AppColors.darkBorderSubtle,
    title: AppColors.darkTextPrimary,
    body: Color(0xFFCBD5E1),
    muted: AppColors.darkTextSecondary,
    accent: Color(0xFF60A5FA),
    primaryBtn: Color(0xFF3B82F6),
  );

  static const List<BoxShadow> _lightShadow = [
    BoxShadow(color: Color(0x080F172A), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Resuelve tokens sin instanciar nuevos objetos en cada hoja del árbol.
  factory HelpThemeTokens.of(BuildContext context) {
    final scoped = HelpHighlightScope.maybeOf(context)?.tokens;
    if (scoped != null) return scoped;
    return AppColors.isDark(context) ? dark : light;
  }

  Color tone(Color c) => isDark ? Color.lerp(c, Colors.white, 0.45)! : c;

  List<BoxShadow>? get shadow => isDark ? null : _lightShadow;
}
