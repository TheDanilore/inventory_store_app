import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';

/// Envoltura global que provee el efecto "Circular Eclipse Wave" al cambiar de tema.
///
/// Captura una instantánea del tema anterior y abre un círculo expansivo en 360°
/// desde la posición del botón con un halo de luz líquido (dorado en amanecer,
/// cyan eléctrico en anochecer) revelando el nuevo tema con cero parpadeos.
class ThemeCircularWave extends StatefulWidget {
  final Widget child;

  const ThemeCircularWave({super.key, required this.child});

  static final GlobalKey<ThemeCircularWaveState> waveKey =
      GlobalKey<ThemeCircularWaveState>();

  /// Método estático global para disparar la transición circular desde cualquier pantalla
  static Future<void> switchTheme(
    BuildContext context, {
    Offset? origin,
    ThemeMode? targetMode,
  }) async {
    final state = waveKey.currentState;
    if (state != null) {
      await state.animateThemeChange(
        context,
        origin: origin,
        targetMode: targetMode,
      );
    } else {
      final cubit = context.read<ThemeCubit>();
      if (targetMode != null) {
        cubit.setThemeMode(targetMode);
      } else {
        cubit.toggleTheme();
      }
    }
  }

  @override
  State<ThemeCircularWave> createState() => ThemeCircularWaveState();
}

class ThemeCircularWaveState extends State<ThemeCircularWave>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller;
  late final Animation<double> _waveAnimation;

  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  bool _isDarkToLight = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );

    _waveAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cleanupSnapshot();
      }
    });
  }

  void _cleanupSnapshot() {
    final oldSnapshot = _snapshot;
    _snapshot = null;
    _isAnimating = false;
    _controller.reset();
    if (mounted) setState(() {});
    // Desecha la imagen fuera del ciclo de dibujo para evitar micro-bloqueos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldSnapshot?.dispose();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  Future<void> animateThemeChange(
    BuildContext context, {
    Offset? origin,
    ThemeMode? targetMode,
  }) async {
    if (_isAnimating) return;

    final cubit = context.read<ThemeCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 1.8);

    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      if (targetMode != null) {
        cubit.setThemeMode(targetMode);
      } else {
        cubit.toggleTheme();
      }
      return;
    }

    final effectiveOrigin =
        origin ?? Offset(screenSize.width - 40, 40); // Cerca del TopBar

    ui.Image? captured;
    try {
      captured = await boundary.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      captured = null;
    }

    if (!mounted) return;

    if (captured == null) {
      if (targetMode != null) {
        cubit.setThemeMode(targetMode);
      } else {
        cubit.toggleTheme();
      }
      return;
    }

    setState(() {
      _isAnimating = true;
      _snapshot = captured;
      _origin = effectiveOrigin;
      _isDarkToLight = isDark; // Si estaba oscuro, transiciona hacia claro
    });

    // 1. Aplica el nuevo tema en el árbol (queda oculto debajo de la máscara instantánea)
    if (targetMode != null) {
      cubit.setThemeMode(targetMode);
    } else {
      cubit.toggleTheme();
    }

    // 2. Inicia la expansión en 360° desde el botón
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // El contenido real del sistema (cambia de tema inmediatamente debajo)
        RepaintBoundary(key: _boundaryKey, child: widget.child),

        // Máscara expansiva del tema anterior con halo de luz
        if (_snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _waveAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CircularEclipseWavePainter(
                      snapshot: _snapshot!,
                      origin: _origin,
                      progress: _waveAnimation.value,
                      isDarkToLight: _isDarkToLight,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Painter que dibuja la captura anterior con un agujero circular expansivo
/// y un anillo perimetral con halo de luz en el frente de onda.
class _CircularEclipseWavePainter extends CustomPainter {
  final ui.Image snapshot;
  final Offset origin;
  final double
  progress; // 0.0 = Círculo en radio 0, 1.0 = Pantalla completa cubierta
  final bool isDarkToLight;

  _CircularEclipseWavePainter({
    required this.snapshot,
    required this.origin,
    required this.progress,
    required this.isDarkToLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Calcula el radio máximo desde el botón a la esquina más lejana
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    double maxRadius = 0;
    for (final c in corners) {
      final d = (c - origin).distance;
      if (d > maxRadius) maxRadius = d;
    }
    maxRadius += 30; // Margen para asegurar cobertura total

    final currentRadius = maxRadius * progress;

    // ── 1. Dibujo de la instantánea previa recortada con agujero circular ──
    final fullRectPath =
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final circleHole =
        Path()..addOval(Rect.fromCircle(center: origin, radius: currentRadius));

    // Todo lo que esté fuera del círculo expansivo muestra el snapshot anterior
    final visiblePath = Path.combine(
      PathOperation.difference,
      fullRectPath,
      circleHole,
    );

    canvas.save();
    canvas.clipPath(visiblePath);

    final srcRect = Rect.fromLTWH(
      0,
      0,
      snapshot.width.toDouble(),
      snapshot.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawImageRect(
      snapshot,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // ── 2. Anillo de Luz Perimetral (Aura líquida expansiva) ───────────────
    if (progress > 0.01 && progress < 0.99) {
      // Color del anillo: dorado ambarino al amanecer, cyan eléctrico al anochecer
      final ringColor =
          isDarkToLight ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);

      final ringAlpha = (1.0 - progress * 0.70).clamp(0.0, 0.85);
      final ringStrokeWidth = 3.5 * (1.0 - progress * 0.6);

      // Halo difuso suave
      final glowPaint =
          Paint()
            ..color = ringColor.withValues(alpha: ringAlpha * 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringStrokeWidth + 6.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawCircle(origin, currentRadius, glowPaint);

      // Borde definido nítido
      final borderPaint =
          Paint()
            ..color = ringColor.withValues(alpha: ringAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ringStrokeWidth;

      canvas.drawCircle(origin, currentRadius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularEclipseWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.origin != origin ||
        oldDelegate.snapshot != snapshot;
  }
}
