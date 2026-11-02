import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_commercial_furniture.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_iso_math.dart';

/// Motor de renderizado isométrico 2.5D (Maqueta arquitectónica interactiva)
class WarehouseIsometricRenderer {
  /// Renderiza la maqueta isométrica completa
  static void paintIsometric({
    required Canvas canvas,
    required Size size,
    required WarehouseLayoutConfig layout,
    required WarehouseZone? selectedZone,
    required bool isDarkMode,
    required double meterScale,
  }) {
    final dim = layout.dimensions;
    final scale = meterScale * 0.88;

    final centerX = size.width / 2;
    final centerY = size.height / 3.4;

    canvas.save();
    canvas.translate(centerX, centerY);

    // 1. Suelo y Baldosas Cerámicas
    _drawIsometricFloorAndTiles(canvas, dim, scale, isDarkMode);

    // 2. Muros perimetrales arquitectónicos (Pared Fondo y Pared Izquierda)
    _drawArchitecturalWalls(canvas, dim, scale, isDarkMode);

    // 3. Ordenar zonas de atrás hacia adelante (Painter's Algorithm: x + y)
    final sortedZones = List<WarehouseZone>.from(layout.zones)
      ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));

    // 4. Dibujar cada elemento detallado
    for (final zone in sortedZones) {
      final isSel = selectedZone?.id == zone.id;
      if (zone.isGlassCounter) {
        WarehouseCommercialFurniture.drawGlassCounter3D(
          canvas: canvas,
          zone: zone,
          scale: scale,
          isSelected: isSel,
        );
      } else if (zone.isFloorFertilizer) {
        WarehouseCommercialFurniture.drawFertilizerPallet3D(
          canvas: canvas,
          zone: zone,
          scale: scale,
          isSelected: isSel,
        );
      } else if (zone.isWallShelf) {
        WarehouseCommercialFurniture.drawWallShelf3D(
          canvas: canvas,
          zone: zone,
          scale: scale,
          isSelected: isSel,
        );
      } else if (zone.isCheckout) {
        WarehouseCommercialFurniture.drawCheckoutDesk3D(
          canvas: canvas,
          zone: zone,
          scale: scale,
          isSelected: isSel,
        );
      } else if (zone.isDoor) {
        WarehouseCommercialFurniture.drawEntranceDoor3D(
          canvas: canvas,
          zone: zone,
          scale: scale,
        );
      } else {
        WarehouseCommercialFurniture.drawIsometricPrism(
          canvas: canvas,
          zone: zone,
          scale: scale,
          isSelected: isSel,
        );
      }
    }

    // 5. Muro Frontal Bajo (Corte Arquitectónico Cutaway)
    _drawCutawayFrontWalls(canvas, dim, scale);

    canvas.restore();
  }

  static void _drawIsometricFloorAndTiles(
    Canvas canvas,
    WarehouseDimensions dim,
    double scale,
    bool isDarkMode,
  ) {
    final w = dim.widthMeters;
    final l = dim.lengthMeters;

    final p0 = WarehouseIsoMath.toIso(0, 0, 0, scale);
    final p1 = WarehouseIsoMath.toIso(w, 0, 0, scale);
    final p2 = WarehouseIsoMath.toIso(w, l, 0, scale);
    final p3 = WarehouseIsoMath.toIso(0, l, 0, scale);

    // Sombra ambiental suave de la losa
    final floorShadow =
        Path()
          ..moveTo(p0.dx, p0.dy + 10)
          ..lineTo(p1.dx + 8, p1.dy + 10)
          ..lineTo(p2.dx + 8, p2.dy + 16)
          ..lineTo(p3.dx - 8, p3.dy + 16)
          ..close();
    canvas.drawPath(floorShadow, WarehousePaintPool.ambientShadowPaint);

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
      WarehousePaintPool.fillPaint..color = floorColor,
    );

    // Baldosas cuadradas comerciales (cada 1.5 metros)
    const tileStep = 1.5;
    final groutPaint =
        WarehousePaintPool.linePaint
          ..color =
              isDarkMode ? const Color(0x2494A3B8) : const Color(0x38FFFFFF)
          ..strokeWidth = 0.9;

    for (double x = 0; x <= w; x += tileStep) {
      final a = WarehouseIsoMath.toIso(x, 0, 0, scale);
      final b = WarehouseIsoMath.toIso(x, l, 0, scale);
      canvas.drawLine(a, b, groutPaint);
    }
    for (double y = 0; y <= l; y += tileStep) {
      final a = WarehouseIsoMath.toIso(0, y, 0, scale);
      final b = WarehouseIsoMath.toIso(w, y, 0, scale);
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
      WarehousePaintPool.fillPaint
        ..color =
            isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
    );
  }

  /// Dibuja los muros altos de fondo y lateral (estilo corte arquitectónico 3D)
  static void _drawArchitecturalWalls(
    Canvas canvas,
    WarehouseDimensions dim,
    double scale,
    bool isDarkMode,
  ) {
    final w = dim.widthMeters;
    final l = dim.lengthMeters;
    final wallH = math.min(3.4, dim.heightMeters);
    const wallThick = 0.35; // Grosor de muro

    // 1. PARED DE FONDO (Along X: de x=0 a x=w, y=-wallThick a y=0, z=0 a z=wallH)
    final b0 = WarehouseIsoMath.toIso(-wallThick, 0, 0, scale);
    final b1 = WarehouseIsoMath.toIso(w, 0, 0, scale);
    final t0 = WarehouseIsoMath.toIso(-wallThick, 0, wallH, scale);
    final t1 = WarehouseIsoMath.toIso(w, 0, wallH, scale);

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
      WarehousePaintPool.fillPaint
        ..color =
            isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
    );

    // 2. PARED LATERAL IZQUIERDA (Along Y: de x=0 a x=-wallThick, y=0 a y=l, z=0 a z=wallH)
    final b3 = WarehouseIsoMath.toIso(0, l, 0, scale);
    final t3 = WarehouseIsoMath.toIso(0, l, wallH, scale);

    final leftWallFace =
        Path()
          ..moveTo(b0.dx, b0.dy)
          ..lineTo(b3.dx, b3.dy)
          ..lineTo(t3.dx, t3.dy)
          ..lineTo(t0.dx, t0.dy)
          ..close();
    canvas.drawPath(
      leftWallFace,
      WarehousePaintPool.fillPaint
        ..color =
            isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
    );

    // Tapa superior del muro (gris grafito arquitectónico)
    final topWallLeft = WarehouseIsoMath.toIso(-wallThick, l, wallH, scale);
    final topWallCorner = WarehouseIsoMath.toIso(
      -wallThick,
      -wallThick,
      wallH,
      scale,
    );
    final topWallRight = WarehouseIsoMath.toIso(w, -wallThick, wallH, scale);

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
      WarehousePaintPool.fillPaint..color = const Color(0xFF1E293B),
    );

    // 3. LETRERO SUPERIOR "INSUMOS AGRÍCOLAS" (Estilo referencia)
    _drawStoreHeaderBanner(canvas, w, wallH, scale);
  }

  static void _drawStoreHeaderBanner(
    Canvas canvas,
    double storeW,
    double wallH,
    double scale,
  ) {
    final bannerW = (storeW * 0.45).clamp(4.0, 7.5);
    final bannerStartX = (storeW - bannerW) / 2;
    final bannerZ = wallH - 0.45;
    const bannerHeight = 0.42;

    final p0 = WarehouseIsoMath.toIso(bannerStartX, 0.05, bannerZ, scale);
    final p1 = WarehouseIsoMath.toIso(
      bannerStartX + bannerW,
      0.05,
      bannerZ,
      scale,
    );
    final p2 = WarehouseIsoMath.toIso(
      bannerStartX + bannerW,
      0.05,
      bannerZ + bannerHeight,
      scale,
    );
    final p3 = WarehouseIsoMath.toIso(
      bannerStartX,
      0.05,
      bannerZ + bannerHeight,
      scale,
    );

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
      WarehousePaintPool.fillPaint..color = const Color(0xFF059669),
    );
    canvas.drawPath(
      bannerPath,
      WarehousePaintPool.strokePaint
        ..color = Colors.white.withValues(alpha: 0.35)
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

  static void _drawCutawayFrontWalls(
    Canvas canvas,
    WarehouseDimensions dim,
    double scale,
  ) {
    // Muro bajo en corte en las caras frontales para no tapar la vista del interior
    final w = dim.widthMeters;
    final l = dim.lengthMeters;
    const curbH = 0.25;

    final b2 = WarehouseIsoMath.toIso(w, l, 0, scale);
    final b3 = WarehouseIsoMath.toIso(0, l, 0, scale);
    final t2 = WarehouseIsoMath.toIso(w, l, curbH, scale);
    final t3 = WarehouseIsoMath.toIso(0, l, curbH, scale);

    final curbFace =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();

    canvas.drawPath(
      curbFace,
      WarehousePaintPool.fillPaint..color = const Color(0xFF334155),
    );
  }
}
