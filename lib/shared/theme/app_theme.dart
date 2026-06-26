import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._(); // Constructor privado para evitar instanciaciones innecesarias

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',

      // =====================================
      // 1. APP BAR (Look Premium: Limpio y Minimalista)
      // =====================================
      appBarTheme: const AppBarTheme(
        backgroundColor:
            AppColors.surface, // Superficie blanca limpia estilo Apple
        foregroundColor:
            AppColors.textPrimary, // Texto oscuro de alta legibilidad
        centerTitle: false, // Alineado a la izquierda es más ejecutivo en ERPs
        elevation: 0,
        scrolledUnderElevation: 1, // Sutil elevación al hacer scroll
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700, // Títulos más robustos
          color: AppColors.textPrimary,
          letterSpacing: -0.6,
        ),
      ),

      // =====================================
      // 2. CAMPOS DE TEXTO (Formularios Consistentes)
      // =====================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            AppColors.radius,
          ), // Consistencia con AppColors
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),

      // =====================================
      // 3. BOTONES (Interactividad Senior)
      // =====================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(
            48,
            48,
          ), // Garantiza el estándar táctil de 48dp
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          // Efecto de interacción al presionar en Material 3
          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return null;
          }),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              AppColors.accent, // Enlaces llamativos en Rojo Vibrante
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radius),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // =====================================
      // 4. COMPONENTES DE NAVEGACIÓN MODERNA (Móvil & Tablet Adaptativo)
      // =====================================
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 4,
        indicatorColor: AppColors.primaryLight, // Globo de selección elegante
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          );
        }),
      ),

      // =====================================
      // 5. CHIPS, DIVISORES Y DIÁLOGOS
      // =====================================
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 24,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          side: const BorderSide(color: AppColors.border),
        ),
        showCheckmark: false,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        elevation: 4,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation:
            0, // Las sombras ahora las maneja nuestro AppColors.cardShadow para un look limpio
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXl),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
