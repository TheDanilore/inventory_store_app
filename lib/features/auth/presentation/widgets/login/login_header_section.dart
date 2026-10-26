import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Cabecera del login bimodal (Modo Claro elegante / Modo Oscuro vidrio).
class LoginHeaderSection extends StatelessWidget {
  final bool isLoginMode;
  final bool showLogo;
  final double logoSize;

  const LoginHeaderSection({
    super.key,
    required this.isLoginMode,
    this.showLogo = true,
    this.logoSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        children: [
          if (showLogo) ...[
            if (isDark)
              Container(
                key: const ValueKey('danilore_one_logo_dark'),
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (context, error, stackTrace) => const Icon(
                        Icons.storefront_rounded,
                        size: 48,
                        color: Color(0xFF22D3EE),
                      ),
                ),
              )
            else
              Container(
                key: const ValueKey('danilore_one_logo_light'),
                height: 85,
                constraints: const BoxConstraints(maxWidth: 190),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Image.asset(
                  'assets/logo_full.png',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (context, error, stackTrace) => const Icon(
                        Icons.storefront_rounded,
                        size: 60,
                        color: AppColors.primary,
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
                color: isDark ? Colors.white : AppColors.textPrimary,
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
