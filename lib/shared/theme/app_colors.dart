import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const bg = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const border = Color(0xFFE8ECF0);
  static const divider = Color(0xFFF1F5F9);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  static const teal = Color(0xFF0D9488);
  static const tealLight = Color(0xFFCCFBF1);
  static const tealDark = Color(0xFF0F766E);

  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFEF3C7);
  static const amberDark = Color(0xFF92400E);

  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFFFE4E6);
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF047857);
  static const successLight = Color(0xFFD1FAE5);

  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0E8);

  static List<BoxShadow> cardShadow({double opacity = 0.06}) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: opacity),
      blurRadius: 14,
      offset: const Offset(0, 3),
    ),
  ];

  static const blue = Color(0xFF0EA5E9);
  static const blueLight = Color(0xFFE0F2FE);

  // --- MANTENIDO: Tu paleta principal (Excelente contraste) ---
  static const Color primary = Color(0xFF1A1A2E); // Deep navy
  static const Color accent = Color(0xFFE94560); // Vibrant red
  static const Color accentLight = Color(0xFFFF6B6B);

  static const Color background = Color(0xFFF4F6F9);

  static const Color gold = Color(0xFFFFB800);
  static const Color goldLight = Color(0xFFFFF3CD);

  // Colores base

  // --- CORREGIDO: Brand Colors armonizados con el Deep Navy ---
  // (Antes eran verdes, ahora son variaciones elegantes de tu color primary)
  static const Color primaryDark = Color(0xFF0F0F1A); // Navy más oscuro
  static const Color primaryLight = Color(
    0xFFE6E6F0,
  ); // Un tono claro del Navy para fondos de iconos

  static const Color textHint = Color(0xFF9CA3AF);

  // --- Semantic & Status ---
  static const Color warning = Color(0xFFF57C00);
  static const Color warningDark = Color(0xFFD17D10);
  static const Color warningLight = Color(0xFFFFF3CD);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF1E88E5);

  // Radio y espaciado

  static const radius = 16.0;
  static const radiusSm = 8.0;
  static const radiusXl = 24.0;
  static const radiusLg = 20.0;

  static const slate = Color(0xFF3D5168);
  static const slateLight = Color(0xFFDFE8F0);

  static BoxDecoration card({Color? borderColor, bool elevated = true}) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusXl),
        border: Border.all(color: borderColor ?? border),
        boxShadow:
            elevated
                ? [
                  BoxShadow(
                    color: const Color(0xFF0D1B2E).withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      );

  // --- CORREGIDO: Material 3 ColorScheme ---
  static const ColorScheme colorScheme = ColorScheme.light(
    primary: primary,
    primaryContainer: primaryLight,
    secondary:
        accent, // ¡Clave! Ahora usa el Rojo Vibrante como color secundario interactivo
    secondaryContainer: accentLight,
    surface: surface,
    error: error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: textPrimary,
    onError: Colors.white,
  );
}
