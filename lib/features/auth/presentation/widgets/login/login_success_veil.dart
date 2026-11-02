import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

const Color _kCyan = Color(0xFF22D3EE);

/// Marca + barra de progreso al iniciar sesión con éxito.
/// Bimodal: Blanco/Azul corporativo en Claro, Vidrio Azul/Cian en Oscuro.
class LoginSuccessVeil extends StatelessWidget {
  final Animation<double> reveal;
  final Animation<double> progress;

  const LoginSuccessVeil({
    super.key,
    required this.reveal,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([reveal, progress]),
      builder: (context, _) {
        final t = reveal.value;
        if (t <= 0) return const SizedBox.shrink();
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: Transform.scale(
              scale: 0.94 + 0.06 * t,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? _kCyan : const Color(0xFF0891B2))
                              .withValues(alpha: isDark ? 0.38 : 0.25),
                          blurRadius: 44,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => Icon(
                            Icons.storefront_rounded,
                            size: 64,
                            color: isDark ? _kCyan : const Color(0xFF0891B2),
                          ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Abriendo tu panel',
                    style: TextStyle(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.78)
                              : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      width: 120,
                      height: 3,
                      child: LinearProgressIndicator(
                        value: progress.value,
                        backgroundColor:
                            isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? _kCyan : const Color(0xFF0891B2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
