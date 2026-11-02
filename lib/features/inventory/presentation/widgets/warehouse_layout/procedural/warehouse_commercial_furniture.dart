import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_iso_math.dart';

/// Renderizador de mobiliario comercial e industrial especializado en proyección isométrica 2.5D
class WarehouseCommercialFurniture {
  /// 1. Mostrador de Vidrio con Tapa de Madera (Vitrinas comerciales con frascos)
  static void drawGlassCounter3D({
    required Canvas canvas,
    required WarehouseZone zone,
    required double scale,
    required bool isSelected,
  }) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    // Coordenadas
    final b0 = WarehouseIsoMath.toIso(x0, y0, 0, scale);
    final b1 = WarehouseIsoMath.toIso(x1, y0, 0, scale);
    final b2 = WarehouseIsoMath.toIso(x1, y1, 0, scale);
    final b3 = WarehouseIsoMath.toIso(x0, y1, 0, scale);

    final t0 = WarehouseIsoMath.toIso(x0, y0, zH, scale);
    final t1 = WarehouseIsoMath.toIso(x1, y0, zH, scale);
    final t2 = WarehouseIsoMath.toIso(x1, y1, zH, scale);
    final t3 = WarehouseIsoMath.toIso(x0, y1, zH, scale);

    // Sombra en el suelo
    final shadow =
        Path()
          ..moveTo(b0.dx + 3, b0.dy + 3)
          ..lineTo(b1.dx + 4, b1.dy + 3)
          ..lineTo(b2.dx + 4, b2.dy + 5)
          ..lineTo(b3.dx + 2, b3.dy + 5)
          ..close();
    canvas.drawPath(shadow, WarehousePaintPool.shadowPaint);

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
      WarehousePaintPool.fillPaint..color = const Color(0xFF1E293B),
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
      WarehousePaintPool.fillPaint..color = const Color(0x667DD3FC),
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
      WarehousePaintPool.fillPaint..color = const Color(0x5538BDF8),
    );

    // Frascos de producto visibles dentro de la vitrina
    final numBottles = (zone.width * 2).clamp(3, 8).toInt();
    final bottleSpacing = zone.width / numBottles;
    for (int i = 0; i < numBottles; i++) {
      final bx = x0 + (i * bottleSpacing) + 0.2;
      final by = (y0 + y1) / 2;
      final bp = WarehouseIsoMath.toIso(bx, by, zH * 0.45, scale);
      canvas.drawCircle(
        bp,
        2.5,
        WarehousePaintPool.fillPaint
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
      WarehousePaintPool.fillPaint..color = const Color(0xFFD97706),
    );

    // Borde de selección o contorno
    final borderPaint =
        WarehousePaintPool.strokePaint
          ..color =
              isSelected ? const Color(0xFF38BDF8) : const Color(0x4D000000)
          ..strokeWidth = isSelected ? 2.5 : 1.0;
    canvas.drawPath(topWood, borderPaint);
    canvas.drawPath(leftGlass, borderPaint);

    drawIsometricBadge(canvas: canvas, zone: zone, t0: t0, t2: t2);
  }

  /// 2. Palet de Fertilizantes en el Suelo (Sacos de UREA / NPK + Bidones)
  static void drawFertilizerPallet3D({
    required Canvas canvas,
    required WarehouseZone zone,
    required double scale,
    required bool isSelected,
  }) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;

    // Tarima / Palet de madera en la base (altura 0.15m)
    final pb0 = WarehouseIsoMath.toIso(x0, y0, 0.15, scale);
    final pb1 = WarehouseIsoMath.toIso(x1, y0, 0.15, scale);
    final pb2 = WarehouseIsoMath.toIso(x1, y1, 0.15, scale);
    final pb3 = WarehouseIsoMath.toIso(x0, y1, 0.15, scale);

    final palletTop =
        Path()
          ..moveTo(pb0.dx, pb0.dy)
          ..lineTo(pb1.dx, pb1.dy)
          ..lineTo(pb2.dx, pb2.dy)
          ..lineTo(pb3.dx, pb3.dy)
          ..close();
    canvas.drawPath(
      palletTop,
      WarehousePaintPool.fillPaint..color = const Color(0xFF78350F),
    );

    // Listones de madera del palet
    final slatPaint =
        WarehousePaintPool.linePaint
          ..color = const Color(0xFF451A03)
          ..strokeWidth = 1.0;
    canvas.drawLine(
      WarehouseIsoMath.toIso(x0 + 0.3, y0, 0.15, scale),
      WarehouseIsoMath.toIso(x0 + 0.3, y1, 0.15, scale),
      slatPaint,
    );
    canvas.drawLine(
      WarehouseIsoMath.toIso(x1 - 0.3, y0, 0.15, scale),
      WarehouseIsoMath.toIso(x1 - 0.3, y1, 0.15, scale),
      slatPaint,
    );

    // Sacos apilados ("UREA" verde / "NPK" amarillo)
    final sackW = (zone.width * 0.45).clamp(0.8, 1.4);
    final sackL = (zone.length * 0.45).clamp(0.8, 1.4);

    // Saco 1: Verde (UREA)
    _drawSack3D(
      canvas: canvas,
      x: x0 + 0.1,
      y: y0 + 0.1,
      z: 0.15,
      w: sackW,
      l: sackL,
      h: 0.35,
      color: const Color(0xFF15803D),
      label: 'UREA',
      scale: scale,
    );
    // Saco 2: Amarillo (NPK)
    _drawSack3D(
      canvas: canvas,
      x: x0 + 0.1,
      y: y0 + 0.1 + sackL,
      z: 0.15,
      w: sackW,
      l: sackL,
      h: 0.35,
      color: const Color(0xFFEAB308),
      label: 'NPK',
      scale: scale,
    );
    // Saco 3: Blanco/Gris superior
    _drawSack3D(
      canvas: canvas,
      x: x0 + 0.15,
      y: y0 + 0.15,
      z: 0.45,
      w: sackW,
      l: sackL,
      h: 0.30,
      color: const Color(0xFFE2E8F0),
      label: 'FERT',
      scale: scale,
    );

    // Bidones plásticos de agroquímicos al costado
    final bidonPos = WarehouseIsoMath.toIso(x1 - 0.4, y0 + 0.4, 0.15, scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: bidonPos, width: 8, height: 12),
        const Radius.circular(2),
      ),
      WarehousePaintPool.fillPaint..color = const Color(0xFF2563EB),
    );

    if (isSelected) {
      canvas.drawPath(
        palletTop,
        WarehousePaintPool.strokePaint
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 3.0,
      );
    }

    drawIsometricBadge(canvas: canvas, zone: zone, t0: pb0, t2: pb2);
  }

  static void _drawSack3D({
    required Canvas canvas,
    required double x,
    required double y,
    required double z,
    required double w,
    required double l,
    required double h,
    required Color color,
    required String label,
    required double scale,
  }) {
    final t0 = WarehouseIsoMath.toIso(x, y, z + h, scale);
    final t1 = WarehouseIsoMath.toIso(x + w, y, z + h, scale);
    final t2 = WarehouseIsoMath.toIso(x + w, y + l, z + h, scale);
    final t3 = WarehouseIsoMath.toIso(x, y + l, z + h, scale);

    final sackTop =
        Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(sackTop, WarehousePaintPool.fillPaint..color = color);

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
  static void drawWallShelf3D({
    required Canvas canvas,
    required WarehouseZone zone,
    required double scale,
    required bool isSelected,
  }) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    // Estructura del estante (Gris oscuro / Madera)
    final t0 = WarehouseIsoMath.toIso(x0, y0, zH, scale);
    final t1 = WarehouseIsoMath.toIso(x1, y0, zH, scale);
    final t2 = WarehouseIsoMath.toIso(x1, y1, zH, scale);
    final t3 = WarehouseIsoMath.toIso(x0, y1, zH, scale);

    final b2 = WarehouseIsoMath.toIso(x1, y1, 0, scale);
    final b3 = WarehouseIsoMath.toIso(x0, y1, 0, scale);

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
      WarehousePaintPool.fillPaint..color = const Color(0xFF047857),
    );

    // Bandejas intermedias con frascos procedurales
    final levels = zone.levels > 1 ? zone.levels : 4;
    for (int lvl = 1; lvl <= levels; lvl++) {
      final shelfZ = (zH / levels) * lvl;
      final sl3 = WarehouseIsoMath.toIso(x0, y1, shelfZ, scale);
      final sl2 = WarehouseIsoMath.toIso(x1, y1, shelfZ, scale);
      canvas.drawLine(
        sl3,
        sl2,
        WarehousePaintPool.linePaint
          ..color = const Color(0xFFFDE68A)
          ..strokeWidth = 1.5,
      );

      // Frascos de pomo en la bandeja
      for (double fx = x0 + 0.3; fx < x1 - 0.2; fx += 0.45) {
        final fp = WarehouseIsoMath.toIso(fx, y1 - 0.1, shelfZ, scale);
        // Cuerpo del frasco
        canvas.drawCircle(
          Offset(fp.dx, fp.dy - 3),
          2.0,
          WarehousePaintPool.fillPaint..color = Colors.white,
        );
        // Tapa verde/roja
        canvas.drawCircle(
          Offset(fp.dx, fp.dy - 5.5),
          1.2,
          WarehousePaintPool.fillPaint..color = const Color(0xFF16A34A),
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
      WarehousePaintPool.fillPaint..color = const Color(0xFF065F46),
    );

    if (isSelected) {
      canvas.drawPath(
        topFace,
        WarehousePaintPool.strokePaint
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 3.0,
      );
    }

    drawIsometricBadge(canvas: canvas, zone: zone, t0: t0, t2: t2);
  }

  /// 4. Escritorio de Ventas / PC y Caja POS
  static void drawCheckoutDesk3D({
    required Canvas canvas,
    required WarehouseZone zone,
    required double scale,
    required bool isSelected,
  }) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    final t0 = WarehouseIsoMath.toIso(x0, y0, zH, scale);
    final t1 = WarehouseIsoMath.toIso(x1, y0, zH, scale);
    final t2 = WarehouseIsoMath.toIso(x1, y1, zH, scale);
    final t3 = WarehouseIsoMath.toIso(x0, y1, zH, scale);

    final b2 = WarehouseIsoMath.toIso(x1, y1, 0, scale);
    final b3 = WarehouseIsoMath.toIso(x0, y1, 0, scale);

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
      WarehousePaintPool.fillPaint..color = const Color(0xFF1E293B),
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
      WarehousePaintPool.fillPaint..color = const Color(0xFF92400E),
    );

    // Monitor LED de computadora sobre la mesa
    final pcPos = WarehouseIsoMath.toIso(
      (x0 + x1) / 2,
      (y0 + y1) / 2,
      zH,
      scale,
    );
    final screenRect = Rect.fromCenter(
      center: Offset(pcPos.dx, pcPos.dy - 10),
      width: 14,
      height: 9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(1.5)),
      WarehousePaintPool.fillPaint..color = const Color(0xFF0F172A),
    );
    // Pantalla azul encendida
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect.deflate(1), const Radius.circular(1)),
      WarehousePaintPool.fillPaint..color = const Color(0xFF38BDF8),
    );
    // Soporte del monitor
    canvas.drawLine(
      Offset(pcPos.dx, pcPos.dy - 5),
      Offset(pcPos.dx, pcPos.dy),
      WarehousePaintPool.linePaint
        ..color = Colors.black
        ..strokeWidth = 1.5,
    );

    if (isSelected) {
      canvas.drawPath(
        topDesk,
        WarehousePaintPool.strokePaint
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 3.0,
      );
    }

    drawIsometricBadge(canvas: canvas, zone: zone, t0: t0, t2: t2);
  }

  /// 5. Puerta de Acceso con Felpudo
  static void drawEntranceDoor3D({
    required Canvas canvas,
    required WarehouseZone zone,
    required double scale,
  }) {
    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;

    // Felpudo de entrada en el suelo
    final f0 = WarehouseIsoMath.toIso(x0, y0, 0.02, scale);
    final f1 = WarehouseIsoMath.toIso(x1, y0, 0.02, scale);
    final f2 = WarehouseIsoMath.toIso(x1, y1, 0.02, scale);
    final f3 = WarehouseIsoMath.toIso(x0, y1, 0.02, scale);

    final mat =
        Path()
          ..moveTo(f0.dx, f0.dy)
          ..lineTo(f1.dx, f1.dy)
          ..lineTo(f2.dx, f2.dy)
          ..lineTo(f3.dx, f3.dy)
          ..close();
    canvas.drawPath(
      mat,
      WarehousePaintPool.fillPaint..color = const Color(0xFF334155),
    );

    // Hoja de la puerta de vidrio entreabierta
    final doorH = 2.4;
    final dt0 = WarehouseIsoMath.toIso(x0, y0, doorH, scale);
    final dt1 = WarehouseIsoMath.toIso(
      x0 + (zone.width * 0.7),
      y1 + 0.3,
      doorH,
      scale,
    );
    final db1 = WarehouseIsoMath.toIso(
      x0 + (zone.width * 0.7),
      y1 + 0.3,
      0.05,
      scale,
    );

    final doorGlass =
        Path()
          ..moveTo(f0.dx, f0.dy)
          ..lineTo(db1.dx, db1.dy)
          ..lineTo(dt1.dx, dt1.dy)
          ..lineTo(dt0.dx, dt0.dy)
          ..close();

    canvas.drawPath(
      doorGlass,
      WarehousePaintPool.fillPaint..color = const Color(0x6693C5FD),
    );
    canvas.drawPath(
      doorGlass,
      WarehousePaintPool.strokePaint
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 1.2,
    );

    drawIsometricBadge(canvas: canvas, zone: zone, t0: dt0, t2: dt1);
  }

  /// 6. Prisma Isométrico Estándar (Racks y Zonas Generales)
  static void drawIsometricPrism({
    required Canvas canvas,
    required WarehouseZone zone,
    required double scale,
    required bool isSelected,
  }) {
    final baseColor = Color(
      zone.colorValue ?? WarehouseIsoMath.getDefaultColor(zone.type),
    );

    final x0 = zone.x;
    final y0 = zone.y;
    final x1 = zone.x + zone.width;
    final y1 = zone.y + zone.length;
    final zH = zone.height;

    final b0 = WarehouseIsoMath.toIso(x0, y0, 0, scale);
    final b1 = WarehouseIsoMath.toIso(x1, y0, 0, scale);
    final b2 = WarehouseIsoMath.toIso(x1, y1, 0, scale);
    final b3 = WarehouseIsoMath.toIso(x0, y1, 0, scale);

    final t0 = WarehouseIsoMath.toIso(x0, y0, zH, scale);
    final t1 = WarehouseIsoMath.toIso(x1, y0, zH, scale);
    final t2 = WarehouseIsoMath.toIso(x1, y1, zH, scale);
    final t3 = WarehouseIsoMath.toIso(x0, y1, zH, scale);

    final shadowPath =
        Path()
          ..moveTo(b0.dx + 2, b0.dy + 3)
          ..lineTo(b1.dx + 4, b1.dy + 3)
          ..lineTo(b2.dx + 4, b2.dy + 5)
          ..lineTo(b3.dx + 2, b3.dy + 5)
          ..close();
    canvas.drawPath(shadowPath, WarehousePaintPool.shadowPaint);

    final leftFace =
        Path()
          ..moveTo(b3.dx, b3.dy)
          ..lineTo(b2.dx, b2.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
    canvas.drawPath(
      leftFace,
      WarehousePaintPool.fillPaint
        ..color = WarehouseIsoMath.adjustColorBrightness(baseColor, 0.80),
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
      WarehousePaintPool.fillPaint
        ..color = WarehouseIsoMath.adjustColorBrightness(baseColor, 0.68),
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
      WarehousePaintPool.fillPaint
        ..color = WarehouseIsoMath.adjustColorBrightness(baseColor, 1.15),
    );

    if (zone.isRack && zone.levels > 1) {
      final shelfPaint =
          WarehousePaintPool.linePaint
            ..color = Colors.white.withValues(alpha: 0.35)
            ..strokeWidth = 1.2;
      for (int i = 1; i < zone.levels; i++) {
        final curZ = (zH / zone.levels) * i;
        final sl3 = WarehouseIsoMath.toIso(x0, y1, curZ, scale);
        final sl2 = WarehouseIsoMath.toIso(x1, y1, curZ, scale);
        final sl1 = WarehouseIsoMath.toIso(x1, y0, curZ, scale);
        canvas.drawLine(sl3, sl2, shelfPaint);
        canvas.drawLine(sl2, sl1, shelfPaint);
      }
    }

    final strokePaint =
        WarehousePaintPool.strokePaint
          ..color =
              isSelected ? Colors.white : Colors.black.withValues(alpha: 0.2)
          ..strokeWidth = isSelected ? 2.2 : 0.8;
    canvas.drawPath(topFace, strokePaint);
    canvas.drawPath(leftFace, strokePaint);
    canvas.drawPath(rightFace, strokePaint);

    if (isSelected) {
      canvas.drawPath(topFace, WarehousePaintPool.selectionGlowPaint);
    }

    drawIsometricBadge(canvas: canvas, zone: zone, t0: t0, t2: t2);
  }

  /// 7. Etiqueta / Badge Flotante Isométrico
  static void drawIsometricBadge({
    required Canvas canvas,
    required WarehouseZone zone,
    required Offset t0,
    required Offset t2,
  }) {
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

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      WarehousePaintPool.fillPaint..color = const Color(0xD90F172A),
    );

    final borderPaint =
        WarehousePaintPool.strokePaint
          ..color = Colors.white.withValues(alpha: 0.28)
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
}
