import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_iso_math.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_isometric_renderer.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_spatial_index.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_topdown_renderer.dart';

export 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/procedural/warehouse_spatial_index.dart'
    show WarehouseViewMode;

/// Motor de Renderizado Procedural para Almacenes y Tiendas (2D Top-Down y 2.5D Isométrico Maqueta Pro).
/// Arquitectura modular de alto rendimiento (60-120 FPS sin saturación de memoria/GC).
class WarehouseProceduralPainter extends CustomPainter {
  final WarehouseLayoutConfig layout;
  final WarehouseViewMode viewMode;
  final WarehouseZone? selectedZone;
  final bool isDarkMode;
  final double meterScale; // Píxeles por metro

  static const double cos30 = WarehouseIsoMath.cos30;
  static const double sin30 = WarehouseIsoMath.sin30;

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
      WarehouseTopDownRenderer.paintTopDown(
        canvas: canvas,
        size: size,
        layout: layout,
        selectedZone: selectedZone,
        isDarkMode: isDarkMode,
        meterScale: meterScale,
      );
    } else {
      WarehouseIsometricRenderer.paintIsometric(
        canvas: canvas,
        size: size,
        layout: layout,
        selectedZone: selectedZone,
        isDarkMode: isDarkMode,
        meterScale: meterScale,
      );
    }
  }

  /// Localiza la zona bajo el cursor o tap del usuario delegando a la indexación espacial
  WarehouseZone? findZoneAt(Offset localPosition, Size size) {
    return WarehouseSpatialIndex.findZoneAt(
      localPosition: localPosition,
      size: size,
      layout: layout,
      viewMode: viewMode,
      meterScale: meterScale,
    );
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
