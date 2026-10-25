import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LoginToggleMode extends StatelessWidget {
  final bool isLoginMode;
  final bool isLoading;
  final VoidCallback onToggle;

  const LoginToggleMode({
    super.key,
    required this.isLoginMode,
    required this.isLoading,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey(isLoginMode),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLoginMode ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? ',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: isLoading ? null : onToggle,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  isLoginMode ? 'Regístrate gratis' : 'Inicia sesión',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: 350.ms)
        .slideY(begin: 0.1, end: 0);
  }
}
