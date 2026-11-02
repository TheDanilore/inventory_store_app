import 'package:flutter/material.dart';

/// Matemáticas trigonométricas, conversiones de color y pool de pinturas para el motor procedural
class WarehouseIsoMath {
  static const double cos30 = 0.86602540378;
  static const double sin30 = 0.5;

  /// Convierte coordenadas métricas 3D (x, y, z) a coordenadas 2D en pantalla bajo proyección isométrica
  static Offset toIso(double x, double y, double z, double scale) {
    final sx = (x - y) * cos30 * scale;
    final sy = (x + y) * sin30 * scale - (z * scale);
    return Offset(sx, sy);
  }

  /// Ajusta el brillo perceptual de un color mediante HSL
  static Color adjustColorBrightness(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    final adjusted = hsl.withLightness(
      (hsl.lightness * factor).clamp(0.0, 1.0),
    );
    return adjusted.toColor();
  }

  /// Colores temáticos institucionales por tipo de zona
  static int getDefaultColor(String type) {
    switch (type) {
      case 'checkout':
        return 0xFF2563EB;
      case 'glass_counter':
      case 'counter':
        return 0xFFF59E0B;
      case 'wall_shelf':
        return 0xFF059669;
      case 'floor_fertilizer':
      case 'pallet_area':
        return 0xFFB45309;
      case 'door':
        return 0xFFEF4444;
      case 'gondola':
        return 0xFF6366F1;
      case 'industrial_rack':
        return 0xFF3B82F6;
      case 'loading_dock':
        return 0xFFF59E0B;
      case 'packing_station':
        return 0xFF8B5CF6;
      case 'backroom':
        return 0xFF64748B;
      default:
        return 0xFF6B7280;
    }
  }
}

/// Pool de instancias Paint reutilizables para eliminar saturación de Garbage Collector
class WarehousePaintPool {
  static final Paint fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint strokePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint linePaint = Paint()..style = PaintingStyle.stroke;

  static final Paint shadowPaint =
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

  static final Paint ambientShadowPaint =
      Paint()
        ..color = const Color(0x26000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

  static final Paint selectionGlowPaint =
      Paint()
        ..color = const Color(0x8038BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
}
