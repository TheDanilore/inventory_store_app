import 'package:flutter/material.dart';

/// Recorta la ventana de escaneo con un overlay oscuro y bordes redondeados.
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;
  final Color overlayColor;

  const ScannerOverlayPainter({
    required this.scanWindow,
    required this.borderRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Usamos PathFillType.evenOdd para vaciar el marco central sin costosas
    // operaciones booleanas (Path.combine), evitando glitches de renderizado en Flutter Web/CanvasKit.
    final path =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(
            RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)),
          );

    final paint =
        Paint()
          ..color = overlayColor
          ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

/// Dibuja 4 esquinas destacadas (corner brackets) alrededor del rectángulo de escaneo.
class CornerBracketPainter extends CustomPainter {
  final Rect scanRect;
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  const CornerBracketPainter({
    required this.scanRect,
    this.color = const Color(0xFF10B981),
    this.cornerLength = 24.0,
    this.strokeWidth = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final l = scanRect.left;
    final t = scanRect.top;
    final r = scanRect.right;
    final b = scanRect.bottom;
    final cl = cornerLength;

    final path =
        Path()
          // Top-left
          ..moveTo(l, t + cl)
          ..lineTo(l, t)
          ..lineTo(l + cl, t)
          // Top-right
          ..moveTo(r - cl, t)
          ..lineTo(r, t)
          ..lineTo(r, t + cl)
          // Bottom-right
          ..moveTo(r, b - cl)
          ..lineTo(r, b)
          ..lineTo(r - cl, b)
          // Bottom-left
          ..moveTo(l + cl, b)
          ..lineTo(l, b)
          ..lineTo(l, b - cl);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerBracketPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect ||
        oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
