import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LoginHeaderSection extends StatelessWidget {
  final bool isLoginMode;
  final bool showLogo;

  const LoginHeaderSection({
    super.key,
    required this.isLoginMode,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          // Contenedor del Logo
          if (showLogo) ...[
            Container(
              key: const ValueKey('danilore_one_logo_header'),
              height: 105,
              constraints: const BoxConstraints(maxWidth: 190),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Image.asset(
                'assets/logo_full.png',
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(
                      Icons.storefront_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Título dinámico con transición suave al alternar login/registro
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              isLoginMode ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
              key: ValueKey<bool>(isLoginMode),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.6,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          // Subtítulo con transición suave
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              isLoginMode
                  ? 'Todo tu negocio en un solo lugar.'
                  : 'Completa tus datos para empezar en Danilore One',
              key: ValueKey<String>(isLoginMode ? 'login_sub' : 'reg_sub'),
              style: const TextStyle(
                color: AppColors.textSecondary,
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
