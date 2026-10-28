import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';

enum WarehouseViewMode { topDown2D, isometric25D }

/// Motor de Renderizado Procedural para Almacenes y Tiendas (2D Top-Down y 2.5D Isométrico Maqueta Pro).
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

    // 1. Fondo de la losa / piso del local (con azulejos sutiles)
    final floorRect = Rect.fromLTWH(0, 0, totalW, totalL);
    final floorPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)
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

    // 3. Muro perimetral exterior
    final wallPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF334155) : const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect, const Radius.circular(8)),
      wallPaint,
    );

    // 4. Dibujar Zonas
    for (final zone in layout.zones) {
      final isSel = selectedZone?.id == zone.id;
      final zRect = Rect.fromLTWH(
        zone.x * meterScale,
        zone.y * meterScale,
        zone.width * meterScale,
        zone.length * meterScale,
      );

      final baseColor = Color(zone.colorValue ?? _getDefaultColor(zone.type));

      if (isSel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(zRect.inflate(3), const Radius.circular(6)),
          Paint()
            ..color = const Color(0x663B82F6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
        );
      }

      final fillPaint =
          Paint()
            ..color = isSel ? baseColor : baseColor.withValues(alpha: 0.85)
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(zRect, const Radius.circular(4)),
        fillPaint,
      );

      final strokePaint =
          Paint()
            ..color = isSel ? Colors.white : baseColor.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? 2.5 : 1.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(zRect, const Radius.circular(4)),
        strokePaint,
      );

      _drawZonePattern2D(canvas, zone, zRect);
      _drawZoneLabel2D(canvas, zone, zRect);
    }

    // 5. Cotas de dimensión en metros
    _drawDimensionLabels2D(canvas, dim, totalW, totalL);

    canvas.restore();
  }

  void _drawZonePattern2D(Canvas canvas, WarehouseZone zone, Rect rect) {
    if (zone.isRack && zone.levels > 1) {
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
      final p =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(rect.center.dx, rect.center.dy - 3), 3.5, p);
    } else if (zone.isGlassCounter) {
      // Línea diagonal de cristal
      final glassPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..strokeWidth = 1.2;
      canvas.drawLine(rect.topLeft, rect.bottomRight, glassPaint);
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

    final pHoriz = TextPainter(
      text: TextSpan(
        text: '${dim.widthMeters.toStringAsFixed(1)} m de frente',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pHoriz.paint(canvas, Offset((w - pHoriz.width) / 2, -18));

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
  // MODO 2: ISOMÉTRICO 2.5D (MAQUETA ARQUITECTÓNICA REALISTA)
  // ===========================================================================
  void _paintIsometric(Canvas canvas, Size size) {
    final dim = layout.dimensions;
    final scale = meterScale * 0.88;

    final centerX = size.width / 2;
    final centerY = size.height / 3.4;

    canvas.save();
    canvas.translate(centerX, centerY);

    // 1. Suelo y Baldosas Cerámicas
    _drawIsometricFloorAndTiles(canvas, dim, scale);

    // 2. Muros perimetrales arquitectónicos (Pared Fondo y Pared Izquierda)
    _drawArchitecturalWalls(canvas, dim, scale);

    // 3. Ordenar zonas de atrás hacia adelante (Painter's Algorithm: x + y)
    final sortedZones = List<WarehouseZone>.from(layout.zones)
      ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));

    // 4. Dibujar cada elemento detallado
    for (final zone in sortedZones) {
      if (zone.isGlassCounter) {
        _drawGlassCounter3D(canvas, zone, scale);
      } else if (zone.isFloorFertilizer) {
        _drawFertilizerPallet3D(canvas, zone, scale);
      } else if (zone.isWallShelf) {
        _drawWallShelf3D(canvas, zone, scale);
      } else if (zone.isCheckout) {
        _drawCheckoutDesk3D(canvas, zone, scale);
      } else if (zone.isDoor) {
        _drawEntranceDoor3D(canvas, zone, scale);
      } else {
        _drawIsometricPrism(canvas, zone, scale);
      }
    }

    // 5. Muro Frontal Bajo (Corte Arquitectónico Cutaway)
    _drawCutawayFrontWalls(canvas, dim, scale);

    canvas.restore();
  }

  Offset _toIso(double x, double y, double z, double scale) {
    final sx = (x - y) * cos30 * scale;
    final sy = (x + y) * sin30 * scale - (z * scale);
    return Offset(sx, sy);
  }

  void _drawIsometricFloorAndTiles(
    Canvas canvas,
    WarehouseDimensions dim,
    double scale,
  ) {
    final w = dim.widthMeters;
    final l = dim.lengthMeters;

    final p0 = _toIso(0, 0, 0, scale);
    final p1 = _toIso(w, 0, 0, scale);
    final p2 = _toIso(w, l, 0, scale);
    final p3 = _toIso(0, l, 0, scale);

    // Sombra ambiental suave de la losa
    final floorShadow =
        Path()
          ..moveTo(p0.dx, p0.dy + 10)
          ..lineTo(p1.dx + 8, p1.dy + 10)
          ..lineTo(p2.dx + 8, p2.dy + 16)
          ..lineTo(p3.dx - 8, p3.dy + 16)
          ..close();
    canvas.drawPath(
      floorShadow,
      Paint()
        ..color = const Color(0x26000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Superficie del suelo (Color baldosa clara institucional)
    final floorPath =
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

    final floorColor =
        isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    canvas.drawPath(
      floorPath,
      Paint()
        ..color = floorColor
        ..style = PaintingStyle.fill,
    );

    // Baldosas cuadradas comerciales (cada 1.5 metros)
    final tileStep = 1.5;
    final groutPaint =
        Paint()
          ..color =
              isDarkMode ? const Color(0x2494A3B8) : const Color(0x38FFFFFF)
          ..strokeWidth = 0.9;

    for (double x = 0; x <= w; x += tileStep) {
      final a = _toIso(x, 0, 0, scale);
      final b = _toIso(x, l, 0, scale);
      canvas.drawLine(a, b, groutPaint);
    }
    for (double y = 0; y <= l; y += tileStep) {
      final a = _toIso(0, y, 0, scale);
      final b = _toIso(w, y, 0, scale);
      canvas.drawLine(a, b, groutPaint);
    }

    // Canto 3D inferior de la losa (grosor de piso)
    final slabFront =
        Path()
          ..moveTo(p3.dx, p3.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p2.dx, p2.dy + 7)
          ..lineTo(p3.dx, p3.dy + 7)
          ..close();
    canvas.drawPath(
      slabFront,
      Paint()
        ..color = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)
        ..style = PaintingStyle.fill,
    );
  }

  /// Dibuja los muros altos de fondo y lateral (estilo corte arquitectónico 3D)
  void _drawArchitecturalWalls(
    Canvas canvas,
    WarehouseDimensions dim,
    double scale,
  ) {
    final w = dim.widthMeters;
    final l = dim.lengthMeters;
    final wallH = math.min(3.4, dim.heightMeters);
    final wallThick = 0.35; // Grosor de muro

    // 1. PARED DE FONDO (Along X: de x=0 a x=w, y=-wallThick a y=0, z=0 a z=wallH)
    final b0 = _toIso(-wallThick, 0, 0, scale);
    final b1 = _toIso(w, 0, 0, scale);
    final t0 = _toIso(-wallThick, 0, wallH, scale);
    final t1 = _toIso(w, 0, wallH, scale);

    // Cara interior visible de la pared del fondo
    final backWallFace =
        Path()
          ..moveTo(b0.dx, b0.dy)
          ..lineTo(b1.dx, b1.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t0.dx, t0.dy)
          ..close();
    canvas.drawPath(
      backWallFace,
      Paint()
        ..color = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)
        ..style = PaintingStyle.fill,
    );

    // 2. PARED LATERAL IZQUIERDA (Along Y: de x=0 a x=-wallThick, y=0 a y=l, z=0 a z=wallH)
    final b3 = _toIso(0, l, 0, scale);
    final t3 = _toIso(0, l, wallH, scale);

    final leftWallFace =
        Path()
          ..moveTo(b0.dx, b0.dy)
          ..lineTo(b3.dx, b3.dy)
          ..lineTo(t3.dx, t3.dy)
          ..lineTo(t0.dx, t0.dy)
          ..close();
    canvas.drawPath(
      leftWallFace,
      Paint()
        ..color = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)
        ..style = PaintingStyle.fill,
    );

    // Tapa superior del muro (gris grafito arquitectónico)
    final topWallLeft = _toIso(-wallThick, l, wallH, scale);
    final topWallCorner = _toIso(-wallThick, -wallThick, wallH, scale);
    final topWallRight = _toIso(w, -wallThick, wallH, scale);

    final topCap =
        Path()
          ..moveTo(topWallLeft.dx, topWallLeft.dy)
          ..lineTo(topWallCorner.dx, topWallCorner.dy)
          ..lineTo(topWallRight.dx, topWallRight.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t0.dx, t0.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      topCap,
      Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill,
    );

    // 3. LETRERO SUPERIOR "INSUMOS AGRÍCOLAS" (Estilo referencia)
    _drawStoreHeaderBanner(canvas, w, wallH, scale);
  }

  void _drawStoreHeaderBanner(
    Canvas canvas,
    double storeW,
    double wallH,
    double scale,
  ) {
    final bannerW = (storeW * 0.45).clamp(4.0, 7.5);
    final bannerStartX = (storeW - bannerW) / 2;
    final bannerZ = wallH - 0.45;
    final bannerHeight = 0.42;

    final p0 = _toIso(bannerStartX, 0.05, bannerZ, scale);
    final p1 = _toIso(bannerStartX + bannerW, 0.05, bannerZ, scale);
    final p2 = _toIso(
      bannerStartX + bannerW,
      0.05,
      bannerZ + bannerHeight,
      scale,
    );
    final p3 = _toIso(bannerStartX, 0.05, bannerZ + bannerHeight, scale);

    final bannerPath =
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close();

    // Fondo verde esmeralda institucional
    canvas.drawPath(
      bannerPath,
      Paint()
        ..color = const Color(0xFF059669)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      bannerPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Texto del Letrero
    final textCenter = Offset((p0.dx + p1.dx) / 2, (p0.dy + p3.dy) / 2);
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🌿 INSUMOS AGRÍCOLAS 🌿',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        textCenter.dx - (textPainter.width / 2),
        textCenter.dy - (textPainter.height / 2),
      ),
    );
  }

  void _drawCutawayFrontWalls(
    Canvas canvas,
    WarehouseDimensions dim,
    double scale,
  ) {
    // Muro bajo en corte en las caras frontales para no tapar la vista del interior
    final w = dim.widthMeters;
    final l = dim.lengthMeters;
    final curbH = 0.25;

    final b2 = _toIso(w, l, 0, scale);
    final b3 = _toIso(0, l, 0, scale);
    final t2 = _toIso(w, l, curbH, scale);
    final t3 = _toIso(0, l, curbH, scale);

    final curbFace =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();

    canvas.drawPath(
      curbFace,
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.fill,
    );
  }

  // ===========================================================================
  // MÓDULOS ESPECIALIZADOS DE LA TIENDA AGRÍCOLA
  // ===========================================================================

  /// 1. Mostrador de Vidrio con Tapa de Madera (Vitrinas comerciales con frascos)
  void _drawGlassCounter3D(Canvas canvas, WarehouseZone zone, double scale) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    final isSel = selectedZone?.id == zone.id;

    // Coordenadas
    final b0 = _toIso(x0, y0, 0, scale);
    final b1 = _toIso(x1, y0, 0, scale);
    final b2 = _toIso(x1, y1, 0, scale);
    final b3 = _toIso(x0, y1, 0, scale);

    final t0 = _toIso(x0, y0, zH, scale);
    final t1 = _toIso(x1, y0, zH, scale);
    final t2 = _toIso(x1, y1, zH, scale);
    final t3 = _toIso(x0, y1, zH, scale);

    // Sombra en el suelo
    final shadow =
        Path()
          ..moveTo(b0.dx + 3, b0.dy + 3)
          ..lineTo(b1.dx + 4, b1.dy + 3)
          ..lineTo(b2.dx + 4, b2.dy + 5)
          ..lineTo(b3.dx + 2, b3.dy + 5)
          ..close();
    canvas.drawPath(
      shadow,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Base inferior oscura (zócalo)
    final zocaloFace =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(b2.dx, b2.dy - 3)
          ..lineTo(b3.dx, b3.dy - 3)
          ..close();
    canvas.drawPath(
      zocaloFace,
      Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill,
    );

    // Cara Frontal Izquierda: Vidrio Translúcido con reflejo
    final leftGlass =
        Path()
          ..moveTo(b3.dx, b3.dy - 3)
          ..lineTo(b2.dx, b2.dy - 3)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      leftGlass,
      Paint()
        ..color = const Color(0x667DD3FC)
        ..style = PaintingStyle.fill,
    );

    // Cara Frontal Derecha: Vidrio Translúcido
    final rightGlass =
        Path()
          ..moveTo(b2.dx, b2.dy - 3)
          ..lineTo(b1.dx, b1.dy - 3)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..close();
    canvas.drawPath(
      rightGlass,
      Paint()
        ..color = const Color(0x5538BDF8)
        ..style = PaintingStyle.fill,
    );

    // Frascos de producto visibles dentro de la vitrina
    final numBottles = (zone.width * 2).clamp(3, 8).toInt();
    final bottleSpacing = zone.width / numBottles;
    for (int i = 0; i < numBottles; i++) {
      final bx = x0 + (i * bottleSpacing) + 0.2;
      final by = (y0 + y1) / 2;
      final bp = _toIso(bx, by, zH * 0.45, scale);
      canvas.drawCircle(
        bp,
        2.5,
        Paint()
          ..color =
              (i % 2 == 0) ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
      );
    }

    // Tapa Superior: Madera Cálida (Roble / Haya)
    final topWood =
        Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      topWood,
      Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.fill,
    );

    // Borde de selección o contorno
    final borderPaint =
        Paint()
          ..color = isSel ? const Color(0xFF38BDF8) : const Color(0x4D000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2.5 : 1.0;
    canvas.drawPath(topWood, borderPaint);
    canvas.drawPath(leftGlass, borderPaint);

    _drawIsometricBadge(canvas, zone, t0, t2);
  }

  /// 2. Palet de Fertilizantes en el Suelo (Sacos de UREA / NPK + Bidones)
  void _drawFertilizerPallet3D(
    Canvas canvas,
    WarehouseZone zone,
    double scale,
  ) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;

    final isSel = selectedZone?.id == zone.id;

    // Tarima / Palet de madera en la base (altura 0.15m)
    final pb0 = _toIso(x0, y0, 0.15, scale);
    final pb1 = _toIso(x1, y0, 0.15, scale);
    final pb2 = _toIso(x1, y1, 0.15, scale);
    final pb3 = _toIso(x0, y1, 0.15, scale);

    final palletTop =
        Path()
          ..moveTo(pb0.dx, pb0.dy)
          ..lineTo(pb1.dx, pb1.dy)
          ..lineTo(pb2.dx, pb2.dy)
          ..lineTo(pb3.dx, pb3.dy)
          ..close();
    canvas.drawPath(
      palletTop,
      Paint()
        ..color = const Color(0xFF78350F)
        ..style = PaintingStyle.fill,
    );

    // Listones de madera del palet
    final slatPaint =
        Paint()
          ..color = const Color(0xFF451A03)
          ..strokeWidth = 1.0;
    canvas.drawLine(
      _toIso(x0 + 0.3, y0, 0.15, scale),
      _toIso(x0 + 0.3, y1, 0.15, scale),
      slatPaint,
    );
    canvas.drawLine(
      _toIso(x1 - 0.3, y0, 0.15, scale),
      _toIso(x1 - 0.3, y1, 0.15, scale),
      slatPaint,
    );

    // Sacos apilados ("UREA" verde / "NPK" amarillo)
    final sackW = (zone.width * 0.45).clamp(0.8, 1.4);
    final sackL = (zone.length * 0.45).clamp(0.8, 1.4);

    // Saco 1: Verde (UREA)
    _drawSack3D(
      canvas,
      x0 + 0.1,
      y0 + 0.1,
      0.15,
      sackW,
      sackL,
      0.35,
      const Color(0xFF15803D),
      'UREA',
      scale,
    );
    // Saco 2: Amarillo (NPK)
    _drawSack3D(
      canvas,
      x0 + 0.1,
      y0 + 0.1 + sackL,
      0.15,
      sackW,
      sackL,
      0.35,
      const Color(0xFFEAB308),
      'NPK',
      scale,
    );
    // Saco 3: Blanco/Gris superior
    _drawSack3D(
      canvas,
      x0 + 0.15,
      y0 + 0.15,
      0.45,
      sackW,
      sackL,
      0.30,
      const Color(0xFFE2E8F0),
      'FERT',
      scale,
    );

    // Bidones plásticos de agroquímicos al costado
    final bidonPos = _toIso(x1 - 0.4, y0 + 0.4, 0.15, scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: bidonPos, width: 8, height: 12),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF2563EB),
    );

    if (isSel) {
      canvas.drawPath(
        palletTop,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    _drawIsometricBadge(canvas, zone, pb0, pb2);
  }

  void _drawSack3D(
    Canvas canvas,
    double x,
    double y,
    double z,
    double w,
    double l,
    double h,
    Color color,
    String label,
    double scale,
  ) {
    final t0 = _toIso(x, y, z + h, scale);
    final t1 = _toIso(x + w, y, z + h, scale);
    final t2 = _toIso(x + w, y + l, z + h, scale);
    final t3 = _toIso(x, y + l, z + h, scale);

    final sackTop =
        Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      sackTop,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    // Texto del saco
    final center = Offset((t0.dx + t2.dx) / 2, (t0.dy + t2.dy) / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 6.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - (tp.width / 2), center.dy - (tp.height / 2)),
    );
  }

  /// 3. Estante de Pared con Insumos (Frascos y Sobres)
  void _drawWallShelf3D(Canvas canvas, WarehouseZone zone, double scale) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    final isSel = selectedZone?.id == zone.id;

    // Estructura del estante (Gris oscuro / Madera)
    final t0 = _toIso(x0, y0, zH, scale);
    final t1 = _toIso(x1, y0, zH, scale);
    final t2 = _toIso(x1, y1, zH, scale);
    final t3 = _toIso(x0, y1, zH, scale);

    final b2 = _toIso(x1, y1, 0, scale);
    final b3 = _toIso(x0, y1, 0, scale);

    // Cara frontal
    final frontFace =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      frontFace,
      Paint()
        ..color = const Color(0xFF047857)
        ..style = PaintingStyle.fill,
    );

    // Bandejas intermedias con frascos procedurales
    final levels = zone.levels > 1 ? zone.levels : 4;
    for (int lvl = 1; lvl <= levels; lvl++) {
      final shelfZ = (zH / levels) * lvl;
      final sl3 = _toIso(x0, y1, shelfZ, scale);
      final sl2 = _toIso(x1, y1, shelfZ, scale);
      canvas.drawLine(
        sl3,
        sl2,
        Paint()
          ..color = const Color(0xFFFDE68A)
          ..strokeWidth = 1.5,
      );

      // Frascos de pomo en la bandeja
      for (double fx = x0 + 0.3; fx < x1 - 0.2; fx += 0.45) {
        final fp = _toIso(fx, y1 - 0.1, shelfZ, scale);
        // Cuerpo del frasco
        canvas.drawCircle(
          Offset(fp.dx, fp.dy - 3),
          2.0,
          Paint()..color = Colors.white,
        );
        // Tapa verde/roja
        canvas.drawCircle(
          Offset(fp.dx, fp.dy - 5.5),
          1.2,
          Paint()..color = const Color(0xFF16A34A),
        );
      }
    }

    // Tapa superior
    final topFace =
        Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      topFace,
      Paint()
        ..color = const Color(0xFF065F46)
        ..style = PaintingStyle.fill,
    );

    if (isSel) {
      canvas.drawPath(
        topFace,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    _drawIsometricBadge(canvas, zone, t0, t2);
  }

  /// 4. Escritorio de Ventas / PC y Caja POS
  void _drawCheckoutDesk3D(Canvas canvas, WarehouseZone zone, double scale) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    final isSel = selectedZone?.id == zone.id;

    final t0 = _toIso(x0, y0, zH, scale);
    final t1 = _toIso(x1, y0, zH, scale);
    final t2 = _toIso(x1, y1, zH, scale);
    final t3 = _toIso(x0, y1, zH, scale);

    final b2 = _toIso(x1, y1, 0, scale);
    final b3 = _toIso(x0, y1, 0, scale);

    // Frontal del escritorio (madera oscura y negro)
    final frontDesk =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      frontDesk,
      Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.fill,
    );

    // Tablero superior de madera
    final topDesk =
        Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      topDesk,
      Paint()
        ..color = const Color(0xFF92400E)
        ..style = PaintingStyle.fill,
    );

    // Monitor LED de computadora sobre la mesa
    final pcPos = _toIso((x0 + x1) / 2, (y0 + y1) / 2, zH, scale);
    final screenRect = Rect.fromCenter(
      center: Offset(pcPos.dx, pcPos.dy - 10),
      width: 14,
      height: 9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF0F172A),
    );
    // Pantalla azul encendida
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect.deflate(1), const Radius.circular(1)),
      Paint()..color = const Color(0xFF38BDF8),
    );
    // Soporte del monitor
    canvas.drawLine(
      Offset(pcPos.dx, pcPos.dy - 5),
      Offset(pcPos.dx, pcPos.dy),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5,
    );

    if (isSel) {
      canvas.drawPath(
        topDesk,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }

    _drawIsometricBadge(canvas, zone, t0, t2);
  }

  /// 5. Puerta de Acceso con Felpudo
  void _drawEntranceDoor3D(Canvas canvas, WarehouseZone zone, double scale) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;

    // Felpudo de entrada en el suelo
    final f0 = _toIso(x0, y0, 0.02, scale);
    final f1 = _toIso(x1, y0, 0.02, scale);
    final f2 = _toIso(x1, y1, 0.02, scale);
    final f3 = _toIso(x0, y1, 0.02, scale);

    final mat =
        Path()
          ..moveTo(f0.dx, f0.dy)
          ..lineTo(f1.dx, f1.dy)
          ..lineTo(f2.dx, f2.dy)
          ..lineTo(f3.dx, f3.dy)
          ..close();
    canvas.drawPath(
      mat,
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.fill,
    );

    // Hoja de la puerta de vidrio entreabierta
    final doorH = 2.4;
    final dt0 = _toIso(x0, y0, doorH, scale);
    final dt1 = _toIso(x0 + (zone.width * 0.7), y1 + 0.3, doorH, scale);
    final db1 = _toIso(x0 + (zone.width * 0.7), y1 + 0.3, 0.05, scale);

    final doorGlass =
        Path()
          ..moveTo(f0.dx, f0.dy)
          ..lineTo(db1.dx, db1.dy)
          ..lineTo(dt1.dx, dt1.dy)
          ..lineTo(dt0.dx, dt0.dy)
          ..close();

    canvas.drawPath(
      doorGlass,
      Paint()
        ..color = const Color(0x6693C5FD)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      doorGlass,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    _drawIsometricBadge(canvas, zone, dt0, dt1);
  }

  void _drawIsometricPrism(Canvas canvas, WarehouseZone zone, double scale) {
    final isSel = selectedZone?.id == zone.id;
    final baseColor = Color(zone.colorValue ?? _getDefaultColor(zone.type));

    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    final b0 = _toIso(x0, y0, 0, scale);
    final b1 = _toIso(x1, y0, 0, scale);
    final b2 = _toIso(x1, y1, 0, scale);
    final b3 = _toIso(x0, y1, 0, scale);

    final t0 = _toIso(x0, y0, zH, scale);
    final t1 = _toIso(x1, y0, zH, scale);
    final t2 = _toIso(x1, y1, zH, scale);
    final t3 = _toIso(x0, y1, zH, scale);

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

    final leftFace =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      leftFace,
      Paint()
        ..color = _adjustColorBrightness(baseColor, 0.80)
        ..style = PaintingStyle.fill,
    );

    final rightFace =
        Path()
          ..moveTo(b2.dx, b2.dy)
          ..lineTo(b1.dx, b1.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..close();
    canvas.drawPath(
      rightFace,
      Paint()
        ..color = _adjustColorBrightness(baseColor, 0.68)
        ..style = PaintingStyle.fill,
    );

    final topFace =
        Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      topFace,
      Paint()
        ..color = _adjustColorBrightness(baseColor, 1.15)
        ..style = PaintingStyle.fill,
    );

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

    final strokePaint =
        Paint()
          ..color = isSel ? Colors.white : Colors.black.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2.2 : 0.8;
    canvas.drawPath(topFace, strokePaint);
    canvas.drawPath(leftFace, strokePaint);
    canvas.drawPath(rightFace, strokePaint);

    if (isSel) {
      final glowPaint =
          Paint()
            ..color = const Color(0x8038BDF8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      canvas.drawPath(topFace, glowPaint);
    }

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
        fontSize: 8.5,
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

    final pillPaint =
        Paint()
          ..color = const Color(0xD90F172A)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      pillPaint,
    );

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
  // HIT-TESTING & COORD TRANSFORMS
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
      final scale = meterScale * 0.88;
      final origin = Offset(size.width / 2, size.height / 3.4);
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
                  poly[j].dx)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  int _getDefaultColor(String type) {
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
