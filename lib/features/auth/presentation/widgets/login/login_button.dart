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

  bool get _locked => widget.isLoading || widget.isSuccess;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final success = widget.isSuccess;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listener (no GestureDetector): responde al instante, sin esperar el
    // timeout de tap, y no compite con el botón interno.
    return Listener(
      onPointerDown: (_) {
        if (!_locked) _setPressed(true);
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          // Al éxito el color migra a verde en lugar de cambiar de golpe
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radius),
            gradient: LinearGradient(
              colors:
                  success
                      ? const [Color(0xFF059669), Color(0xFF10B981)]
                      : (isDark
                          ? const [Color(0xFF1D6FF2), Color(0xFF06B6D4)]
                          : const [Color(0xFF1E2038), AppColors.primary]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (success
                        ? const Color(0xFF10B981)
                        : (isDark
                            ? const Color(0xFF06B6D4)
                            : AppColors.primary))
                    .withValues(alpha: success ? 0.35 : (isDark ? 0.25 : 0.30)),
                blurRadius: _isPressed ? 8 : 16,
                offset: Offset(0, _isPressed ? 3 : 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _locked ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child:
                  success
                      ? Row(
                        key: const ValueKey('success_state'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // El check "rebota" al aparecer
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            builder:
                                (context, v, child) =>
                                    Transform.scale(scale: v, child: child),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
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
                      ? Row(
                        key: const ValueKey('loading_state'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.isLoginMode
                                ? 'Verificando…'
                                : 'Creando cuenta…',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                      : Row(
                        key: ValueKey(widget.isLoginMode),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isLoginMode
                                ? 'Iniciar sesión'
                                : 'Crear cuenta',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
