import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_iso_math.dart';

/// Motor de renderizado en 2D (Plano técnico cenital)
class WarehouseTopDownRenderer {
  /// Renderiza el plano técnico 2D centrado en el canvas
  static void paintTopDown({
    required Canvas canvas,
    required Size size,
    required WarehouseLayoutConfig layout,
    required WarehouseZone? selectedZone,
    required bool isDarkMode,
    required double meterScale,
  }) {
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
        WarehousePaintPool.fillPaint
          ..color =
              isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(floorRect, const Radius.circular(8)),
      floorPaint,
    );

    // 2. Cuadrícula técnica (grid de 1 metro)
    final gridPaint =
        WarehousePaintPool.linePaint
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
        WarehousePaintPool.strokePaint
          ..color =
              isDarkMode ? const Color(0xFF334155) : const Color(0xFF475569)
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

      final baseColor = Color(
        zone.colorValue ?? WarehouseIsoMath.getDefaultColor(zone.type),
      );

      if (isSel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(zRect.inflate(3), const Radius.circular(6)),
          WarehousePaintPool.selectionGlowPaint,
        );
      }

      final fillPaint =
          WarehousePaintPool.fillPaint
            ..color = isSel ? baseColor : baseColor.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(zRect, const Radius.circular(4)),
        fillPaint,
      );

      final strokePaint =
          WarehousePaintPool.strokePaint
            ..color = isSel ? Colors.white : baseColor.withValues(alpha: 0.9)
            ..strokeWidth = isSel ? 2.5 : 1.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(zRect, const Radius.circular(4)),
        strokePaint,
      );

      _drawZonePattern2D(canvas, zone, zRect);
      _drawZoneLabel2D(canvas, zone, zRect);
    }

    // 5. Cotas de dimensión en metros
    _drawDimensionLabels2D(canvas, dim, totalW, totalL, isDarkMode);

    canvas.restore();
  }

  static void _drawZonePattern2D(Canvas canvas, WarehouseZone zone, Rect rect) {
    if (zone.isRack && zone.levels > 1) {
      final dividerPaint =
          WarehousePaintPool.linePaint
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
          WarehousePaintPool.strokePaint
            ..color = Colors.white.withValues(alpha: 0.5)
            ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(rect.center.dx, rect.center.dy - 3), 3.5, p);
    } else if (zone.isGlassCounter) {
      // Línea diagonal de cristal
      final glassPaint =
          WarehousePaintPool.linePaint
            ..color = Colors.white.withValues(alpha: 0.4)
            ..strokeWidth = 1.2;
      canvas.drawLine(rect.topLeft, rect.bottomRight, glassPaint);
    }
  }

  static void _drawZoneLabel2D(Canvas canvas, WarehouseZone zone, Rect rect) {
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

  static void _drawDimensionLabels2D(
    Canvas canvas,
    WarehouseDimensions dim,
    double w,
    double l,
    bool isDarkMode,
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
}
