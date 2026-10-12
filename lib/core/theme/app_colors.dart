import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- 1. COLORES DE FONDO Y SUPERFICIES (Modo Claro - Look Apple HIG / Linear) ---
  static const Color background = Color(
    0xFFF8FAFC,
  ); // Slate 50: canvas limpio, descansa la vista
  static const Color surface = Colors.white; // Tarjetas y contenedores
  static const Color surfaceDark = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0); // Bordes limpios definidos
  static const Color divider = Color(0xFFE2E8F0); // Separadores sutiles

  // --- 1.1 SIDEBAR EXECUTIVE LIGHT ---
  static const Color sidebarBg = Color(0xFFFFFFFF); // Blanco puro
  static const Color sidebarBorder = Color(0xFFE2E8F0); // Borde fino Slate 200
  static const Color sidebarText = Color(
    0xFF64748B,
  ); // Slate 500 elegante inactivo
  static const Color sidebarTextActive = Color(
    0xFF1E40AF,
  ); // Blue 800 texto activo
  static const Color sidebarActiveBg = Color(
    0xFFEFF6FF,
  ); // Blue 50 cápsula activa suave
  static const Color sidebarActiveIndicator = Color(
    0xFF2563EB,
  ); // Blue 600 vibrante
  static const Color sidebarHover = Color(0xFFF8FAFC); // Slate 50 hover sutil
  static const Color sidebarSectionHeader = Color(0xFF94A3B8); // Slate 400

  // --- 1.2 MODO OSCURO EJECUTIVO (Midnight Slate / Linear - Deep Navy) ---
  static const Color darkBackground = Color(
    0xFF0B0F19,
  ); // Midnight Charcoal Canvas
  static const Color darkSurface = Color(
    0xFF111827,
  ); // Slate 900 Tarjetas & Tablas
  static const Color darkSurfaceElevated = Color(
    0xFF1E293B,
  ); // Slate 800 Popups, Modales, Toolbars
  static const Color darkSurfaceHighlight = Color(
    0xFF253347,
  ); // Slate 750 Hover & Selecciones
  static const Color darkBorder = Color(0xFF1E293B); // Borde Slate 800 sutil
  static const Color darkBorderSubtle = Color(
    0xFF334155,
  ); // Borde Slate 700 para inputs y foco
  static const Color darkDivider = Color(0xFF1E293B);

  // --- 1.3 SIDEBAR EXECUTIVE DARK / MIDNIGHT ---
  static const Color darkSidebarBg = Color(0xFF0F172A); // Slate 900
  static const Color darkSidebarBorder = Color(0xFF1E293B);
  static const Color darkSidebarText = Color(0xFF94A3B8); // Slate 400
  static const Color darkSidebarTextActive = Color(0xFF60A5FA); // Blue 400
  static const Color darkSidebarActiveBg = Color(0xFF1E293B); // Slate 800
  static const Color darkSidebarActiveIndicator = Color(0xFF3B82F6); // Blue 500
  static const Color darkSidebarHover = Color(0xFF1E293B);
  static const Color darkSidebarSectionHeader = Color(0xFF64748B); // Slate 500

  // --- 2. TIPOGRAFÍA REFINADA (Slate Palette) ---
  static const slate = Color(0xFF3D5168);
  static const slateLight = Color(0xFFDFE8F0);

  static const Color textPrimary = Color(0xFF0F172A); // Títulos (Slate 900)
  static const Color textSecondary = Color(
    0xFF64748B,
  ); // Subtítulos (Slate 600)
  static const Color textMuted = Color(
    0xFF94A3B8,
  ); // Hints y desactivados (Slate 400)

  // Tipografía Modo Oscuro
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500

  // --- 3. COLORES DE MARCA (Deep Navy & Vibrant Red) ---
  static const Color primary = Color(0xFF1A1A2E); // Navy Principal Profundo
  static const Color primaryDark = Color(
    0xFF0F0F1A,
  ); // Navy para estados oscuros
  static const Color primaryLight = Color(
    0xFFE6E6F0,
  ); // Fondo claro para iconos de marca

  static const Color accent = Color(0xFFE94560); // Rojo Vibrante
  static const Color accentLight = Color(0xFFFF6B6B);

  static const Color gold = Color(0xFFFFB800);
  static const Color goldLight = Color(0xFFFFF3CD);

  // --- 4. PALETA SEMÁNTICA Y ESTADOS DEL ERP ---
  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFFCCFBF1);
  static const Color tealDark = Color(0xFF0F766E);

  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFEF3C7);
  static const amberDark = Color(0xFF92400E);

  static const danger = Color(0xFFEF4444);
  static const dangerDark = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFFE4E6);
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF047857);
  static const successLight = Color(0xFFD1FAE5);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFFE4E6);

  static const Color info = Color(0xFF0EA5E9);
  static const Color infoLight = Color(0xFFE0F2FE);

  // --- 5. COMPONENTES VISUALES Y SOMBRAS PREMIUM ---
  static const double radiusSm = 8.0;
  static const double radius = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;

  static List<BoxShadow> cardShadow({double opacity = 0.04}) => [
    BoxShadow(
      color: const Color(0xFF0D1B2E).withValues(alpha: opacity),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> darkCardShadow({double opacity = 0.25}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 18,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration card({Color? borderColor, bool elevated = true}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: borderColor ?? border),
        boxShadow: elevated ? cardShadow() : null,
      );

  static BoxDecoration cardAdaptive(
    BuildContext context, {
    Color? borderColor,
    bool elevated = true,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: dark ? darkSurface : surface,
      borderRadius: BorderRadius.circular(radiusLg),
      border: Border.all(color: borderColor ?? (dark ? darkBorder : border)),
      boxShadow: elevated ? (dark ? darkCardShadow() : cardShadow()) : null,
    );
  }

  // --- 6. HELPERS ADAPTATIVOS POR CONTEXTO ---
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBackground : background;

  static Color surf(BuildContext context) =>
      isDark(context) ? darkSurface : surface;

  static Color surfElevated(BuildContext context) =>
      isDark(context) ? darkSurfaceElevated : Colors.white;

  static Color brd(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color brdSubtle(BuildContext context) =>
      isDark(context) ? darkBorderSubtle : border;

  static Color txtPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color txtSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color txtMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color sideBg(BuildContext context) =>
      isDark(context) ? darkSidebarBg : sidebarBg;

  static Color sideBorder(BuildContext context) =>
      isDark(context) ? darkSidebarBorder : sidebarBorder;

  // --- 7. CONFIGURACIÓN DEL MATERIAL 3 ---
  static const ColorScheme colorScheme = ColorScheme.light(
    primary: primary,
    primaryContainer: primaryLight,
    secondary: primary,
    secondaryContainer: primaryLight,
    surface: surface,
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: textPrimary,
    onError: Colors.white,
  );

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: Color(0xFF3B82F6), // Blue 500
    primaryContainer: Color(0xFF1E3A8A), // Blue 900
    secondary: Color(0xFF10B981), // Emerald 500
    secondaryContainer: Color(0xFF064E3B), // Emerald 900
    surface: darkSurface,
    surfaceContainerHighest: darkSurfaceElevated,
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: darkTextPrimary,
    onError: Colors.white,
  );
}
