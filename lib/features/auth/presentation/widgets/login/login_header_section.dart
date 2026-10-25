import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LoginHeaderSection extends StatelessWidget {
  final bool isLoginMode;

  const LoginHeaderSection({super.key, required this.isLoginMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          // Contenedor del Logo con sutil sombra difuminada y animación de entrada
          Container(
                height: 110,
                constraints: const BoxConstraints(maxWidth: 190),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
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
              )
              .animate()
              .fadeIn(duration: 500.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              )
              .then()
              .shimmer(
                delay: 2000.ms,
                duration: 1800.ms,
                color: Colors.white.withValues(alpha: 0.6),
              ),
          const SizedBox(height: 18),
          // Título dinámico con transición suave al alternar login/registro
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.15),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
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
            duration: const Duration(milliseconds: 300),
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
