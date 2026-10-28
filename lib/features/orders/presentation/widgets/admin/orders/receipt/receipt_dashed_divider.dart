import 'package:flutter/material.dart';

/// Divisor punteado / discontinuo de alto rendimiento pintado directamente sobre el Canvas.
/// Reemplaza la creación de ~80 widgets SizedBox individuales en el árbol de renderizado.
class ReceiptDashedDivider extends StatelessWidget {
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;
  final Color color;

  const ReceiptDashedDivider({
    super.key,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
    this.strokeWidth = 1.0,
    this.color = const Color(0xFFCBD5E1),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashedLinePainter(
        dashWidth: dashWidth,
        dashSpace: dashSpace,
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;
  final Color color;

  _DashedLinePainter({
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      final endX = (startX + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
