import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- 1. COLORES DE FONDO Y SUPERFICIES (Look Premium Estilo Stripe) ---
  static const Color background = Color(0xFFF4F6F9); // Fondo general limpio
  static const Color surface = Colors.white; // Tarjetas y contenedores
  static const Color surfaceDark = Color(0xFFF4F6F9);
  static const Color border = Color(0xFFE8ECF0); // Bordes sutiles
  static const Color divider = Color(0xFFF1F5F9); // Separadores delgados

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

  // --- 3. COLORES DE MARCA (Deep Navy & Vibrant Red) ---
  static const Color primary = Color(0xFF1A1A2E); // Navy Principal Profundo
  static const Color primaryDark = Color(
    0xFF0F0F1A,
  ); // Navy para estados oscuros
  static const Color primaryLight = Color(
    0xFFE6E6F0,
  ); // Fondo claro para iconos de marca

  static const Color accent = Color(
    0xFFE94560,
  ); // Rojo Vibrante (Acciones/Interacción)
  static const Color accentLight = Color(0xFFFF6B6B); // Variación clara

  static const Color gold = Color(0xFFFFB800);
  static const Color goldLight = Color(0xFFFFF3CD);

  // --- 4. PALETA SEMÁNTICA Y ESTADOS DEL ERP ---
  // Teal (Ideal para Ventas / Ingresos / Stock Disponible)
  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFFCCFBF1);
  static const Color tealDark = Color(0xFF0F766E);

  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFEF3C7);
  static const amberDark = Color(0xFF92400E);

  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFFE4E6);
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF047857);
  static const successLight = Color(0xFFD1FAE5);

  // Amber/Gold (Ideal para Alertas de Stock Bajo / Lotes por Vencer)
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);

  // Error/Danger (Ideal para Pérdidas / Ajustes Negativos / Cancelaciones)
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFFE4E6);

  // Info/Blue (Ideal para Guías de Remisión / Datos del Proveedor)
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoLight = Color(0xFFE0F2FE);

  // --- 5. COMPONENTES VISUALES Y SOMBRAS PREMIUM (Efecto Elevación Difusa) ---
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

  static BoxDecoration card({Color? borderColor, bool elevated = true}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(
          radiusLg,
        ), // Optimizado a Lg para mejor estética móvil/tablet
        border: Border.all(color: borderColor ?? border),
        boxShadow: elevated ? cardShadow() : null,
      );

  // --- 6. CONFIGURACIÓN DEL MATERIAL 3 COLOR SCHEME CORREGIDO ---
  static const ColorScheme colorScheme = ColorScheme.light(
    primary: primary,
    primaryContainer: primaryLight,
    secondary: accent, // El rojo vibrante actúa como secundario interactivo
    secondaryContainer: accentLight,
    surface: surface,
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: textPrimary,
    onError: Colors.white,
  );
}
