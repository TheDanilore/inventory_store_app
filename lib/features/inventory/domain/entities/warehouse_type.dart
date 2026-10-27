import 'package:flutter/material.dart';

/// Tipología operativa del nodo de inventario (Almacén o Tienda).
enum WarehouseType {
  store(
    'store',
    'Tienda / Sucursal',
    Icons.storefront_rounded,
    Color(0xFF10B981),
  ),
  central(
    'warehouse',
    'Almacén Central / Depósito',
    Icons.warehouse_rounded,
    Color(0xFF3B82F6),
  ),
  darkStore(
    'dark_store',
    'Dark Store / Express',
    Icons.bolt_rounded,
    Color(0xFF8B5CF6),
  ),
  transit(
    'transit',
    'Móvil / En Tránsito',
    Icons.local_shipping_rounded,
    Color(0xFFF59E0B),
  );

  final String value;
  final String label;
  final IconData icon;
  final Color brandColor;

  const WarehouseType(this.value, this.label, this.icon, this.brandColor);

  static WarehouseType fromString(String? val) {
    if (val == null) return WarehouseType.central;
    switch (val.toLowerCase().trim()) {
      case 'store':
      case 'tienda':
      case 'sucursal':
        return WarehouseType.store;
      case 'dark_store':
      case 'darkstore':
      case 'micro_hub':
        return WarehouseType.darkStore;
      case 'transit':
      case 'movil':
      case 'transito':
        return WarehouseType.transit;
      case 'warehouse':
      case 'almacen':
      case 'central':
      default:
        return WarehouseType.central;
    }
  }
}
