import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';

enum WarehouseViewMode { topDown2D, isometric25D }

/// Motor de Renderizado Procedural para Almacenes y Tiendas (2D Top-Down y 2.5D Isométrico).
class WarehouseProceduralPainter extends CustomPainter {
  final WarehouseLayoutConfig layout;
  final WarehouseViewMode viewMode;
  final WarehouseZone? selectedZone;
  final bool isDarkMode;
  final double meterScale; // Píxeles por metro

  static const double cos30 = 0.86602540378;
  static const double sin30 = 0.5;

  WarehouseProceduralPainter({
    required this.layout,
    this.viewMode = WarehouseViewMode.isometric25D,
    this.selectedZone,
    this.isDarkMode = false,
    this.meterScale = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (viewMode == WarehouseViewMode.topDown2D) {
      _paintTopDown(canvas, size);
    } else {
      _paintIsometric(canvas, size);
    }
  }

  // ===========================================================================
  // MODO 1: TOP-DOWN (PLANO TÉCNICO 2D)
  // ===========================================================================
  void _paintTopDown(Canvas canvas, Size size) {
    final dim = layout.dimensions;
    final totalW = dim.widthMeters * meterScale;
    final totalL = dim.lengthMeters * meterScale;

    // Centrar en el canvas
    final originX = (size.width - totalW) / 2;
    final originY = (size.height - totalL) / 2;

    canvas.save();
    canvas.translate(originX, originY);

    // 1. Fondo de la losa / piso del local
    final floorRect = Rect.fromLTWH(0, 0, totalW, totalL);
    final floorPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect, const Radius.circular(8)),
      floorPaint,
    );

    // 2. Cuadrícula técnica (grid de 1 metro)
    final gridPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0x1A94A3B8) : const Color(0x1F64748B)
          ..strokeWidth = 0.8;

    for (double x = 0; x <= totalW; x += meterScale) {
      canvas.drawLine(Offset(x, 0), Offset(x, totalL), gridPaint);
    }
    for (double y = 0; y <= totalL; y += meterScale) {
      canvas.drawLine(Offset(0, y), Offset(totalW, y), gridPaint);
    }

    // 3. Muro perimetral
    final wallPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF334155) : const Color(0xFF94A3B8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect, const Radius.circular(8)),
      wallPaint,
    );

    // 4. Dibujar Zonas (Mobiliario, Racks, Góndolas, Cajas)
    for (final zone in layout.zones) {
      final isSel = selectedZone?.id == zone.id;
      final zRect = Rect.fromLTWH(
        zone.x * meterScale,
        zone.y * meterScale,
        zone.width * meterScale,
        zone.length * meterScale,
      );

      final baseColor = Color(zone.colorValue ?? _getDefaultColor(zone.type));

      // Sombra si está seleccionado
      if (isSel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(zRect.inflate(3), const Radius.circular(6)),
          Paint()
            ..color = const Color(0x663B82F6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
        );
      }

      // Relleno de la zona
      final fillPaint =
          Paint()
            ..color = isSel ? baseColor : baseColor.withValues(alpha: 0.85)
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(zRect, const Radius.circular(4)),
        fillPaint,
      );

      // Borde
      final strokePaint =
          Paint()
            ..color = isSel ? Colors.white : baseColor.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? 2.5 : 1.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(zRect, const Radius.circular(4)),
        strokePaint,
      );

      // Rayado interior si es rack (niveles) o checkout
      _drawZonePattern2D(canvas, zone, zRect);

      // Etiqueta de texto (Código o Nombre)
      _drawZoneLabel2D(canvas, zone, zRect);
    }

    // 5. Cotas de dimensión en metros (ancho y fondo)
    _drawDimensionLabels2D(canvas, dim, totalW, totalL);

    canvas.restore();
  }

  void _drawZonePattern2D(Canvas canvas, WarehouseZone zone, Rect rect) {
    if (zone.isRack && zone.levels > 1) {
      // Líneas divisorias de niveles
      final dividerPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..strokeWidth = 1.0;
      final step = rect.height / zone.levels;
      for (int i = 1; i < zone.levels; i++) {
        final lineY = rect.top + (step * i);
        canvas.drawLine(
          Offset(rect.left, lineY),
          Offset(rect.right, lineY),
          dividerPaint,
        );
      }
    } else if (zone.isCheckout) {
      // Pequeño ícono de mostrador / caja
      final p =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(rect.center.dx, rect.center.dy - 4), 4, p);
    }
  }

  void _drawZoneLabel2D(Canvas canvas, WarehouseZone zone, Rect rect) {
    if (rect.width < 18 || rect.height < 14) return;

    final text = zone.code ?? zone.name;
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: math.min(10.0, rect.width * 0.18),
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '..',
    )..layout(maxWidth: rect.width - 4);

    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - (textPainter.width / 2),
        rect.center.dy - (textPainter.height / 2),
      ),
    );
  }

  void _drawDimensionLabels2D(
    Canvas canvas,
    WarehouseDimensions dim,
    double w,
    double l,
  ) {
    final style = TextStyle(
      color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    // Cota horizontal
    final pHoriz = TextPainter(
      text: TextSpan(
        text: '${dim.widthMeters.toStringAsFixed(1)} m de frente',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pHoriz.paint(canvas, Offset((w - pHoriz.width) / 2, -18));

    // Cota vertical
    final pVert = TextPainter(
      text: TextSpan(
        text: '${dim.lengthMeters.toStringAsFixed(1)} m de fondo',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pVert.paint(canvas, Offset(w + 8, (l - pVert.height) / 2));
  }

  // ===========================================================================
  // MODO 2: ISOMÉTRICO 2.5D (GEMELO DIGITAL AXONOMÉTRICO)
  // ===========================================================================
  void _paintIsometric(Canvas canvas, Size size) {
    final dim = layout.dimensions;
    final scale = meterScale * 0.85;

    // Centro del canvas como punto focal
    final centerX = size.width / 2;
    final centerY = size.height / 3;

    canvas.save();
    canvas.translate(centerX, centerY);

    // 1. Suelo isométrico (Plataforma del local)
    _drawIsometricFloor(canvas, dim, scale);

    // 2. Ordenar zonas por profundidad (Painter's Algorithm: de atrás hacia adelante)
    // Coordenada de profundidad isométrica: x + y
    final sortedZones = List<WarehouseZone>.from(layout.zones)
      ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));

    // 3. Dibujar cada prisma 3D (Zonas, Racks, Góndolas)
    for (final zone in sortedZones) {
      _drawIsometricPrism(canvas, zone, scale);
    }

    canvas.restore();
  }

  Offset _toIso(double x, double y, double z, double scale) {
    // Proyección isométrica estándar:
    // ScreenX = (x - y) * cos(30) * scale
    // ScreenY = (x + y) * sin(30) * scale - (z * scale)
    final sx = (x - y) * cos30 * scale;
    final sy = (x + y) * sin30 * scale - (z * scale);
    return Offset(sx, sy);
  }

  void _drawIsometricFloor(
    Canvas canvas,
    WarehouseDimensions dim,
    double scale,
  ) {
    final p0 = _toIso(0, 0, 0, scale);
    final p1 = _toIso(dim.widthMeters, 0, 0, scale);
    final p2 = _toIso(dim.widthMeters, dim.lengthMeters, 0, scale);
    final p3 = _toIso(0, dim.lengthMeters, 0, scale);

    // Sombra proyectada del suelo/plataforma en el espacio virtual
    final floorShadow =
        Path()
          ..moveTo(p0.dx, p0.dy + 8)
          ..lineTo(p1.dx + 6, p1.dy + 8)
          ..lineTo(p2.dx + 6, p2.dy + 12)
          ..lineTo(p3.dx - 6, p3.dy + 12)
          ..close();
    canvas.drawPath(
      floorShadow,
      Paint()
        ..color = const Color(0x1F000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Suelo base
    final floorPath =
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

    final floorPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)
          ..style = PaintingStyle.fill;
    canvas.drawPath(floorPath, floorPaint);

    // Grosor de la losa arquitectónica (canto 3D)
    final slabFront =
        Path()
          ..moveTo(p3.dx, p3.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p2.dx, p2.dy + 5)
          ..lineTo(p3.dx, p3.dy + 5)
          ..close();
    canvas.drawPath(
      slabFront,
      Paint()
        ..color = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.fill,
    );

    // Cuadrícula isométrica
    final gridPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0x1494A3B8) : const Color(0x1F64748B)
          ..strokeWidth = 0.8;

    for (double x = 0; x <= dim.widthMeters; x += 2.0) {
      final a = _toIso(x, 0, 0, scale);
      final b = _toIso(x, dim.lengthMeters, 0, scale);
      canvas.drawLine(a, b, gridPaint);
    }
    for (double y = 0; y <= dim.lengthMeters; y += 2.0) {
      final a = _toIso(0, y, 0, scale);
      final b = _toIso(dim.widthMeters, y, 0, scale);
      canvas.drawLine(a, b, gridPaint);
    }

    // Borde perimetral del local
    final borderPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    canvas.drawPath(floorPath, borderPaint);
  }

  void _drawIsometricPrism(Canvas canvas, WarehouseZone zone, double scale) {
    final isSel = selectedZone?.id == zone.id;
    final baseColor = Color(zone.colorValue ?? _getDefaultColor(zone.type));

    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    // Coordenadas base (z = 0)
    final b0 = _toIso(x0, y0, 0, scale);
    final b1 = _toIso(x1, y0, 0, scale);
    final b2 = _toIso(x1, y1, 0, scale);
    final b3 = _toIso(x0, y1, 0, scale);

    // Coordenadas superiores (z = zH)
    final t0 = _toIso(x0, y0, zH, scale);
    final t1 = _toIso(x1, y0, zH, scale);
    final t2 = _toIso(x1, y1, zH, scale);
    final t3 = _toIso(x0, y1, zH, scale);

    // Sombra en el suelo
    final shadowPath =
        Path()
          ..moveTo(b0.dx + 2, b0.dy + 3)
          ..lineTo(b1.dx + 4, b1.dy + 3)
          ..lineTo(b2.dx + 4, b2.dy + 5)
          ..lineTo(b3.dx + 2, b3.dy + 5)
          ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 1. Cara Frontal Izquierda (b3 -> b2 -> t2 -> t3)
    final leftFace =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    final leftColor = _adjustColorBrightness(baseColor, 0.80);
    canvas.drawPath(
      leftFace,
      Paint()
        ..color = leftColor
        ..style = PaintingStyle.fill,
    );

    // 2. Cara Frontal Derecha (b2 -> b1 -> t1 -> t2)
    final rightFace =
        Path()
          ..moveTo(b2.dx, b2.dy)
          ..lineTo(b1.dx, b1.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..close();
    final rightColor = _adjustColorBrightness(baseColor, 0.68);
    canvas.drawPath(
      rightFace,
      Paint()
        ..color = rightColor
        ..style = PaintingStyle.fill,
    );

    // 3. Cara Superior / Techo (t0 -> t1 -> t2 -> t3)
    final topFace =
        Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    final topColor = _adjustColorBrightness(baseColor, 1.15);
    canvas.drawPath(
      topFace,
      Paint()
        ..color = topColor
        ..style = PaintingStyle.fill,
    );

    // Si es rack con niveles, dibujar líneas de bandejas en las caras frontales
    if (zone.isRack && zone.levels > 1) {
      final shelfPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..strokeWidth = 1.2;
      for (int i = 1; i < zone.levels; i++) {
        final curZ = (zH / zone.levels) * i;
        final sl3 = _toIso(x0, y1, curZ, scale);
        final sl2 = _toIso(x1, y1, curZ, scale);
        final sl1 = _toIso(x1, y0, curZ, scale);
        canvas.drawLine(sl3, sl2, shelfPaint);
        canvas.drawLine(sl2, sl1, shelfPaint);
      }
    }

    // Contorno y resaltado si está seleccionado
    final strokePaint =
        Paint()
          ..color = isSel ? Colors.white : Colors.black.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2.2 : 0.8;
    canvas.drawPath(topFace, strokePaint);
    canvas.drawPath(leftFace, strokePaint);
    canvas.drawPath(rightFace, strokePaint);

    // Glow de selección
    if (isSel) {
      final glowPaint =
          Paint()
            ..color = const Color(0x8038BDF8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      canvas.drawPath(topFace, glowPaint);
    }

    // Badge o código flotante sobre el techo de la zona
    _drawIsometricBadge(canvas, zone, t0, t2);
  }

  void _drawIsometricBadge(
    Canvas canvas,
    WarehouseZone zone,
    Offset t0,
    Offset t2,
  ) {
    final centerTop = Offset((t0.dx + t2.dx) / 2, (t0.dy + t2.dy) / 2);
    final text = zone.code ?? zone.name;

    final span = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );

    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = tp.width + 10;
    final badgeHeight = tp.height + 4;
    final badgeRect = Rect.fromCenter(
      center: centerTop,
      width: badgeWidth,
      height: badgeHeight,
    );

    // Pill de alto contraste tipo HUD / CAD digital twin
    final pillPaint =
        Paint()
          ..color = const Color(0xB80F172A)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      pillPaint,
    );

    // Borde sutil del badge
    final borderPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      borderPaint,
    );

    tp.paint(
      canvas,
      Offset(centerTop.dx - (tp.width / 2), centerTop.dy - (tp.height / 2)),
    );
  }

  // ===========================================================================
  // BÚSQUEDA DE ZONA / SELECCIÓN (Detección de click/tap en estantes)
  // ===========================================================================
  WarehouseZone? findZoneAt(Offset localPosition, Size size) {
    if (viewMode == WarehouseViewMode.topDown2D) {
      final dim = layout.dimensions;
      final totalW = dim.widthMeters * meterScale;
      final totalL = dim.lengthMeters * meterScale;
      final originX = (size.width - totalW) / 2;
      final originY = (size.height - totalL) / 2;

      final relPos = localPosition - Offset(originX, originY);
      final meterX = relPos.dx / meterScale;
      final meterY = relPos.dy / meterScale;

      for (final zone in layout.zones.reversed) {
        if (meterX >= zone.x &&
            meterX <= zone.x + zone.width &&
            meterY >= zone.y &&
            meterY <= zone.y + zone.length) {
          return zone;
        }
      }
    } else {
      // Isométrico: hit test ordenado de más cercano a más lejano
      final scale = meterScale * 0.85;
      final origin = Offset(size.width / 2, size.height / 3);
      final relPos = localPosition - origin;

      final sorted = List<WarehouseZone>.from(layout.zones)
        ..sort((a, b) => (b.x + b.y).compareTo(a.x + a.y));

      for (final zone in sorted) {
        final b3 = _toIso(zone.x, zone.y + zone.length, 0, scale);
        final b2 = _toIso(zone.x + zone.width, zone.y + zone.length, 0, scale);
        final b1 = _toIso(zone.x + zone.width, zone.y, 0, scale);
        final t0 = _toIso(zone.x, zone.y, zone.height, scale);
        final t1 = _toIso(zone.x + zone.width, zone.y, zone.height, scale);
        final t2 = _toIso(
          zone.x + zone.width,
          zone.y + zone.length,
          zone.height,
          scale,
        );
        final t3 = _toIso(zone.x, zone.y + zone.length, zone.height, scale);

        // Polígono envolvente del prisma proyectado
        final poly = [t0, t1, t2, b1, b2, b3, t3];
        if (_pointInPolygon(relPos, poly)) {
          return zone;
        }
      }
    }
    return null;
  }

  bool _pointInPolygon(Offset p, List<Offset> poly) {
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      if ((poly[i].dy > p.dy) != (poly[j].dy > p.dy) &&
          (p.dx <
              (poly[j].dx - poly[i].dx) *
                      (p.dy - poly[i].dy) /
                      (poly[j].dy - poly[i].dy) +
                  poly[i].dx)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================
  int _getDefaultColor(String type) {
    switch (type) {
      case 'checkout':
        return 0xFF2563EB; // Azul cobalto (Caja / PC vendedor)
      case 'glass_counter':
      case 'counter':
        return 0xFFF59E0B; // Ámbar dorado cristal (Mostrador de vidrio / vitrina)
      case 'wall_shelf':
        return 0xFF059669; // Verde esmeralda bosque (Estantería pared)
      case 'floor_fertilizer':
      case 'pallet_area':
        return 0xFFB45309; // Ocre tierra (Sacos de abono en suelo)
      case 'door':
        return 0xFFEF4444; // Rojo coral (Puerta / Acceso)
      case 'gondola':
        return 0xFF6366F1; // Índigo moderno (exhibición tienda)
      case 'industrial_rack':
        return 0xFF3B82F6; // Azul cobalto (racks industriales)
      case 'loading_dock':
        return 0xFFF59E0B; // Ámbar logístico (muelle)
      case 'packing_station':
        return 0xFF8B5CF6; // Púrpura (preparación y despacho)
      case 'backroom':
        return 0xFF64748B; // Pizarra / Gris acero (trastienda)
      default:
        return 0xFF6B7280;
    }
  }

  Color _adjustColorBrightness(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    final adjusted = hsl.withLightness(
      (hsl.lightness * factor).clamp(0.0, 1.0),
    );
    return adjusted.toColor();
  }

  @override
  bool shouldRepaint(covariant WarehouseProceduralPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.viewMode != viewMode ||
        oldDelegate.selectedZone != selectedZone ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.meterScale != meterScale;
  }
}
