import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Botón volver adaptativo para la pantalla de inicio de sesión.
class LoginBackButton extends StatelessWidget {
  final bool isDark;

  const LoginBackButton({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    if (!context.canPop()) {
      return const SizedBox.shrink();
    }
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    if (isDesktop) {
      return TextButton.icon(
        onPressed: () => context.pop(),
        icon: Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.textSecondary,
        ),
        label: Text(
          'Volver',
          style: TextStyle(
            color:
                isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return _MobileBackButton(isDark: isDark);
  }
}

class _MobileBackButton extends StatefulWidget {
  final bool isDark;
  const _MobileBackButton({this.isDark = false});

  @override
  State<_MobileBackButton> createState() => _MobileBackButtonState();
}

class _MobileBackButtonState extends State<_MobileBackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  widget.isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(11),
              boxShadow:
                  widget.isDark ? null : AppColors.cardShadow(opacity: 0.08),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: widget.isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          onPressed: () => context.pop(),
        ),
      ),
    );
  }
}
