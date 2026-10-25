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

class _LiquidLightButtonState extends State<LiquidLightButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beamCtrl;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _beamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isLoading) {
      _beamCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(LiquidLightButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _beamCtrl.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _beamCtrl.stop();
      _beamCtrl.reset();
    }
  }

  @override
  void dispose() {
    _beamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWorking = widget.isLoading || widget.isSuccess;

    return GestureDetector(
      onTapDown: isWorking ? null : (_) => setState(() => _isPressed = true),
      onTapUp: isWorking ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: isWorking ? null : () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radius),
            boxShadow: [
              if (widget.isSuccess)
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.40),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              else if (widget.isLoading)
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.30),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radius),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Fondo del haz de luz perimetral en rotación (cuando isLoading está activo)
                if (widget.isLoading)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _beamCtrl,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _LiquidBeamPainter(
                            angle: _beamCtrl.value * 2 * math.pi,
                          ),
                        );
                      },
                    ),
                  )
                else if (widget.isSuccess)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),

                // 2. Núcleo interior del botón (deja visible el borde perimetral de luz líquida)
                Positioned.fill(
                  child: Container(
                    margin: EdgeInsets.all(widget.isLoading ? 2.0 : 0.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        widget.isLoading
                            ? (AppColors.radius - 2)
                            : AppColors.radius,
                      ),
                      gradient:
                          widget.isSuccess
                              ? const LinearGradient(
                                colors: [Color(0xFF059669), Color(0xFF10B981)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : const LinearGradient(
                                colors: [Color(0xFF1C1E34), Color(0xFF121324)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                    ),
                  ),
                ),

                // 3. Contenido interactivo con animación fluida entre estados
                Positioned.fill(
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
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child:
                          widget.isSuccess
                              ? const Row(
                                key: ValueKey('success_state'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Acceso Concedido',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              )
                              : widget.isLoading
                              ? Row(
                                key: const ValueKey('loading_state'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PulseDot(delay: 0),
                                  const SizedBox(width: 6),
                                  _PulseDot(delay: 150),
                                  const SizedBox(width: 6),
                                  _PulseDot(delay: 300),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Sincronizando...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              )
                              : Text(
                                widget.isLoginMode
                                    ? 'Iniciar sesión'
                                    : 'Crear cuenta',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter que dibuja el haz de luz líquida de neón recorriendo el perímetro
class _LiquidBeamPainter extends CustomPainter {
  final double angle;

  _LiquidBeamPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint =
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: 0.0,
            endAngle: math.pi * 2,
            transform: GradientRotation(angle),
            colors: const [
              Colors.transparent,
              Color(0xFF3B82F6), // Electric Blue
              Color(0xFF00F0FF), // Neon Cyan Beam
              Color(0xFFE94560), // Crimson Accent
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 0.70, 0.90, 1.0],
          ).createShader(rect);

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_LiquidBeamPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

/// Orbe de pulso luminoso sincronizado para el interior del loader
class _PulseDot extends StatefulWidget {
  final int delay;

  const _PulseDot({required this.delay});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _ctrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00F0FF),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
