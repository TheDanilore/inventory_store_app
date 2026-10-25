import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';

/// Botón con micro-interacción "Eclipse Morphing" para alternar entre
/// Modo Claro (Sol dorado con rayos) y Modo Oscuro (Luna creciente con estrellas).
class ThemeEclipseButton extends StatefulWidget {
  final bool isDark;
  final void Function(Offset globalOrigin)? onTapWithOrigin;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  const ThemeEclipseButton({
    super.key,
    required this.isDark,
    this.onTapWithOrigin,
    this.onTap,
    this.size = 38.0,
    this.tooltip,
  });

  @override
  State<ThemeEclipseButton> createState() => _ThemeEclipseButtonState();
}

class _ThemeEclipseButtonState extends State<ThemeEclipseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _morphAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.isDark ? 1.0 : 0.0,
    );

    _morphAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  @override
  void didUpdateWidget(covariant ThemeEclipseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      if (widget.isDark) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context) {
    AppFeedbackService.vibrate(durationMs: 35, amplitude: 90);

    final renderBox = context.findRenderObject() as RenderBox?;
    Offset? origin;
    if (renderBox != null && renderBox.hasSize) {
      origin = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    }

    if (widget.onTapWithOrigin != null && origin != null) {
      widget.onTapWithOrigin!(origin);
    } else if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final buttonWidget = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () => _handleTap(context),
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : (_isHovered ? 1.04 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      isDark
                          ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.20),
                  blurRadius: _isHovered ? 14 : 8,
                  spreadRadius: _isHovered ? 1 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _morphAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size * 0.58, widget.size * 0.58),
                    painter: _EclipseMorphPainter(
                      progress: _morphAnimation.value,
                      backgroundColor:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}

/// Painter vectorial que transforma suavemente un Sol en una Luna creciente
class _EclipseMorphPainter extends CustomPainter {
  final double
  progress; // 0.0 = Sol radiante, 1.0 = Luna creciente con estrellas
  final Color backgroundColor;

  _EclipseMorphPainter({required this.progress, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.32;

    // Colores interpolados (Sol dorado -> Luna cyan celestial)
    final celestialColor =
        Color.lerp(
          const Color(0xFFF59E0B), // Ámbar solar
          const Color(0xFF38BDF8), // Cyan estelar lunar
          progress,
        ) ??
        const Color(0xFFF59E0B);

    // ── 1. Rayos Solares (Se contraen, rotan y se ocultan hacia el núcleo) ──
    final rayContract = (1.0 - progress * 1.4).clamp(0.0, 1.0);
    if (rayContract > 0.02) {
      final rayPaint =
          Paint()
            ..color = celestialColor.withValues(alpha: rayContract * 0.95)
            ..strokeWidth = 1.8 * rayContract
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;

      const rayCount = 8;
      final rayRotation = progress * (math.pi / 2); // Rota 90° al contraerse
      final rayStart = radius + 2.0;
      final rayLength = (size.width * 0.16) * rayContract;

      for (int i = 0; i < rayCount; i++) {
        final angle = (i * 2 * math.pi / rayCount) + rayRotation;
        final p1 = Offset(
          center.dx + math.cos(angle) * rayStart,
          center.dy + math.sin(angle) * rayStart,
        );
        final p2 = Offset(
          center.dx + math.cos(angle) * (rayStart + rayLength),
          center.dy + math.sin(angle) * (rayStart + rayLength),
        );
        canvas.drawLine(p1, p2, rayPaint);
      }
    }

    // ── 2. Cuerpo Celestial (Sol / Eclipse -> Luna Creciente) ────────────────
    final celestialPaint =
        Paint()
          ..color = celestialColor
          ..style = PaintingStyle.fill;

    // Círculo base celestial
    final sunPath =
        Path()..addOval(Rect.fromCircle(center: center, radius: radius));

    // Máscara curva de eclipse que entra desde arriba a la derecha
    // A progress 0.0: está lejos afuera del sol
    // A progress 1.0: se posiciona para formar la media luna perfecta
    final maskOffsetFactor = 1.4 - (0.88 * progress);
    final maskCenter = Offset(
      center.dx + radius * maskOffsetFactor,
      center.dy - radius * maskOffsetFactor,
    );
    final maskRadius = radius * 0.88;

    final maskPath =
        Path()
          ..addOval(Rect.fromCircle(center: maskCenter, radius: maskRadius));

    // Sustracción booleana: Sol - Máscara = Luna creciente suave
    final moonPath = Path.combine(PathOperation.difference, sunPath, maskPath);
    canvas.drawPath(moonPath, celestialPaint);

    // ── 3. Micro-estrellas brillantes en Modo Noche (Aparecen al final) ─────
    if (progress > 0.35) {
      final starOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
      final starColor = const Color(
        0xFFBAE6FD,
      ).withValues(alpha: starOpacity * 0.9);

      // Estrella mayor superior derecha
      _drawSparkleStar(
        canvas: canvas,
        center: Offset(center.dx + radius * 0.72, center.dy - radius * 0.65),
        radius: size.width * 0.11 * starOpacity,
        color: starColor,
      );

      // Estrella menor inferior derecha
      _drawSparkleStar(
        canvas: canvas,
        center: Offset(center.dx + radius * 0.95, center.dy + radius * 0.38),
        radius: size.width * 0.07 * starOpacity,
        color: starColor.withValues(alpha: starOpacity * 0.7),
      );
    }
  }

  void _drawSparkleStar({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required Color color,
  }) {
    if (radius <= 0.1) return;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path = Path();
    final half = radius * 0.35;

    // Estrella de 4 puntas estilizada
    path.moveTo(center.dx, center.dy - radius);
    path.lineTo(center.dx + half, center.dy);
    path.lineTo(center.dx, center.dy + radius);
    path.lineTo(center.dx - half, center.dy);
    path.close();

    path.moveTo(center.dx - radius, center.dy);
    path.lineTo(center.dx, center.dy + half);
    path.lineTo(center.dx + radius, center.dy);
    path.lineTo(center.dx, center.dy - half);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EclipseMorphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
