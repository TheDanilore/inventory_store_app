import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLoginMode ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? ',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        MouseRegion(
          cursor:
              isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: isLoading ? null : onToggle,
            child: Text(
              isLoginMode ? 'Regístrate gratis' : 'Inicia sesión',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
