import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_iso_math.dart';

enum WarehouseViewMode { topDown2D, isometric25D }

/// Algoritmo de hit-testing espacial de alto rendimiento para el plano y maqueta de almacén
class WarehouseSpatialIndex {
  /// Localiza la zona seleccionada bajo las coordenadas de pantalla del canvas
  static WarehouseZone? findZoneAt({
    required Offset localPosition,
    required Size size,
    required WarehouseLayoutConfig layout,
    required WarehouseViewMode viewMode,
    required double meterScale,
  }) {
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
        final b3 = WarehouseIsoMath.toIso(zone.x, zone.y + zone.length, 0, scale);
        final b2 = WarehouseIsoMath.toIso(
          zone.x + zone.width,
          zone.y + zone.length,
          0,
          scale,
        );
        final b1 = WarehouseIsoMath.toIso(zone.x + zone.width, zone.y, 0, scale);
        final t0 = WarehouseIsoMath.toIso(zone.x, zone.y, zone.height, scale);
        final t1 = WarehouseIsoMath.toIso(
          zone.x + zone.width,
          zone.y,
          zone.height,
          scale,
        );
        final t2 = WarehouseIsoMath.toIso(
          zone.x + zone.width,
          zone.y + zone.length,
          zone.height,
          scale,
        );
        final t3 = WarehouseIsoMath.toIso(
          zone.x,
          zone.y + zone.length,
          zone.height,
          scale,
        );

        final poly = [t0, t1, t2, b1, b2, b3, t3];
        if (pointInPolygon(relPos, poly)) {
          return zone;
        }
      }
    }
    return null;
  }

  /// Comprobación geométrica punto-en-polígono (Ray casting algorithm)
  static bool pointInPolygon(Offset p, List<Offset> poly) {
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
}
