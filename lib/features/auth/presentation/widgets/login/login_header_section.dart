import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Cabecera del login: Emblema circular de la marca con resplandor turquesa,
/// título y subtítulo adaptados según el tema.
class LoginHeaderSection extends StatelessWidget {
  final bool isLoginMode;
  final bool showLogo;
  final double logoSize;

  const LoginHeaderSection({
    super.key,
    required this.isLoginMode,
    this.showLogo = true,
    this.logoSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor =
        isDark ? const Color(0xFF22D3EE) : const Color(0xFF0891B2);

    return Center(
      child: Column(
        children: [
          if (showLogo) ...[
            Container(
              key: const ValueKey('danilore_one_logo_header'),
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: isDark ? 0.35 : 0.25),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => Icon(
                      Icons.storefront_rounded,
                      size: logoSize * 0.75,
                      color: glowColor,
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder:
                (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
            child: Text(
              isLoginMode ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
              key: ValueKey<String>(
                '${isDark ? 'dark' : 'light'}_$isLoginMode',
              ),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.6,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder:
                (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
            child: Text(
              isLoginMode
                  ? 'Todo tu negocio en un solo lugar.'
                  : 'Completa tus datos para empezar en Danilore One',
              key: ValueKey<String>(
                '${isDark ? 'dark' : 'light'}_${isLoginMode ? 'login_sub' : 'reg_sub'}',
              ),
              style: TextStyle(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.66)
                        : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
