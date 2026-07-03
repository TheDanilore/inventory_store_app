import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:inventory_store_app/models/customer_location.dart';

// ── Marcador decorativo para ubicaciones guardadas ────────────────────────────────────
class MapMarker extends StatelessWidget {
  final CustomerLocation location;
  final Color color;
  final IconData icon;

  const MapMarker({
    super.key,
    required this.location,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        CustomPaint(size: const Size(12, 8), painter: PinTailPainter(color)),
      ],
    );
  }
}

// ── Pin Central (Modo Selección Estilo Uber) ────────────────────────────────────
class MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool isPicked;

  const MapPin({
    super.key,
    required this.color,
    required this.icon,
    this.isPicked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: isPicked ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        CustomPaint(size: const Size(12, 8), painter: PinTailPainter(color)),
      ],
    );
  }
}

// ── Cola (Triángulo) para los pines ────────────────────────────────────
class PinTailPainter extends CustomPainter {
  final Color color;
  const PinTailPainter(this.color);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()..color = color;
    final path =
        ui.Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0)
          ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
