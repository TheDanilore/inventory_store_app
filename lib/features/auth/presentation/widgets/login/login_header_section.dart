import 'package:flutter/material.dart';

/// Cabecera del login (versión oscura / vidrio).
/// Muestra el ícono de la marca con un halo turquesa, el título y el subtítulo.
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
              key: ValueKey<bool>(isLoginMode),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
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
              key: ValueKey<String>(isLoginMode ? 'login_sub' : 'reg_sub'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
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
