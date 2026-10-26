import 'package:flutter/material.dart';
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

  static const _cyan = Color(0xFF22D3EE);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Row(
        key: ValueKey('${isDark ? 'dark' : 'light'}_$isLoginMode'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isLoginMode ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? ',
            style: TextStyle(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.62)
                      : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton(
            onPressed: isLoading ? null : onToggle,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: isDark ? _cyan : const Color(0xFF2563EB),
            ),
            child: Text(
              isLoginMode ? 'Regístrate gratis' : 'Inicia sesión',
              style: TextStyle(
                color: isDark ? _cyan : const Color(0xFF2563EB),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
