import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LiquidLightButton extends StatefulWidget {
  final bool isLoading;
  final bool isSuccess;
  final bool isLoginMode;
  final VoidCallback onPressed;

  const LiquidLightButton({
    super.key,
    required this.isLoading,
    this.isSuccess = false,
    required this.isLoginMode,
    required this.onPressed,
  });

  @override
  State<LiquidLightButton> createState() => _LiquidLightButtonState();
}

class _LiquidLightButtonState extends State<LiquidLightButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isWorking = widget.isLoading || widget.isSuccess;

    return GestureDetector(
      onTapDown: isWorking ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isWorking ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: isWorking ? null : () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radius),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E2038), AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isWorking ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: child,
                  ),
                );
              },
              child:
                  widget.isSuccess
                      ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('success_icon'),
                        color: Colors.white,
                        size: 24,
                      )
                      : widget.isLoading
                      ? const AppModernSpinner(
                        key: ValueKey('loading_spinner'),
                        size: 22,
                        strokeWidth: 2.6,
                        color: Colors.white,
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

/// Spinner moderno de alta gama con desvanecimiento de estela, punta redondeada y pista translúcida.
class AppModernSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const AppModernSpinner({
    super.key,
    this.size = 22,
    this.strokeWidth = 2.6,
    this.color = Colors.white,
  });

  @override
  State<AppModernSpinner> createState() => _AppModernSpinnerState();
}

class _AppModernSpinnerState extends State<AppModernSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return CustomPaint(
            painter: _ModernSpinnerPainter(
              progress: _ctrl.value,
              strokeWidth: widget.strokeWidth,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _ModernSpinnerPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  _ModernSpinnerPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Pista sutil translúcida de fondo
    final trackPaint =
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Arco con gradiente rotatorio (SweepGradient) con punta redondeada
    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = progress * 2 * math.pi;
    const sweepAngle = 1.5 * math.pi; // 270 grados elegante

    final arcPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: 0.0,
            endAngle: sweepAngle,
            colors: [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.35),
              color,
            ],
            stops: const [0.0, 0.45, 1.0],
            transform: GradientRotation(startAngle),
          ).createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(_ModernSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
