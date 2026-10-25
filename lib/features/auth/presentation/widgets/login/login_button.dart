import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LoginButton extends StatefulWidget {
  final bool isLoading;
  final bool isSuccess;
  final bool isLoginMode;
  final VoidCallback onPressed;

  const LoginButton({
    super.key,
    required this.isLoading,
    this.isSuccess = false,
    required this.isLoginMode,
    required this.onPressed,
  });

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.isLoading ? null : (_) => setState(() => _isPressed = true),
      onTapUp:
          widget.isLoading ? null : (_) => setState(() => _isPressed = false),
      onTapCancel:
          widget.isLoading ? null : () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radius),
            gradient: LinearGradient(
              colors:
                  widget.isSuccess
                      ? const [Color(0xFF059669), Color(0xFF10B981)]
                      : const [Color(0xFF1E2038), AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isSuccess
                        ? const Color(0xFF10B981)
                        : AppColors.primary)
                    .withValues(alpha: widget.isSuccess ? 0.35 : 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed:
                widget.isLoading || widget.isSuccess ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child:
                  widget.isSuccess
                      ? const Row(
                        key: ValueKey('success_state'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '¡Acceso Autorizado!',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                      : widget.isLoading
                      ? const SizedBox(
                        key: ValueKey('loading_spinner'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        widget.isLoginMode ? 'Iniciar sesión' : 'Crear cuenta',
                        key: ValueKey(widget.isLoginMode),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
