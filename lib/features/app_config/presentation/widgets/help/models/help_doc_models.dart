import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Modelo de datos para una pestaña del Centro de Ayuda.
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

/// Tokens semánticos de diseño para el Centro de Ayuda (Claro / Oscuro).
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

  factory HelpThemeTokens.of(BuildContext context) {
    final dark = AppColors.isDark(context);
    return HelpThemeTokens(
      isDark: dark,
      bg: AppColors.bg(context),
      surface: AppColors.surf(context),
      field: dark ? AppColors.darkBackground : AppColors.surfaceDark,
      border: AppColors.brd(context),
      strongBorder: dark ? AppColors.darkBorderSubtle : const Color(0xFFCBD5E1),
      title: AppColors.txtPrimary(context),
      body: dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      muted: AppColors.txtSecondary(context),
      accent: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      primaryBtn: dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
    );
  }

  Color tone(Color c) => isDark ? Color.lerp(c, Colors.white, 0.45)! : c;

  List<BoxShadow>? get shadow =>
      isDark ? null : AppColors.cardShadow(opacity: 0.03);
}
