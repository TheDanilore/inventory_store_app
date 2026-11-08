import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

/// Datos de catálogos en memoria L1 para el formulario de entradas de inventario.
class InventoryEntryCatalogCacheData {
  final List<WarehouseEntity> warehouses;
  final List<SupplierEntity> suppliers;
  final List<FinancialAccountEntity> accounts;
  final Map<String, String> activeShiftsByAccount;
  final DateTime cachedAt;

  InventoryEntryCatalogCacheData({
    required this.warehouses,
    required this.suppliers,
    required this.accounts,
    required this.activeShiftsByAccount,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  bool get isValid =>
      DateTime.now().difference(cachedAt) < const Duration(minutes: 10);
}

/// Caché L1 Singleton en RAM para garantizar Zero-Shimmer (Frame-0)
/// al abrir o regresar al formulario de Entradas de Inventario.
class InventoryEntryCatalogCache {
  InventoryEntryCatalogCache._();

  static final InventoryEntryCatalogCache instance =
      InventoryEntryCatalogCache._();

  InventoryEntryCatalogCacheData? _cached;

  InventoryEntryCatalogCacheData? getCached() {
    if (_cached != null && _cached!.isValid) {
      return _cached;
    }
    return null;
  }

  void put({
    required List<WarehouseEntity> warehouses,
    required List<SupplierEntity> suppliers,
    required List<FinancialAccountEntity> accounts,
    required Map<String, String> activeShiftsByAccount,
  }) {
    _cached = InventoryEntryCatalogCacheData(
      warehouses: List.unmodifiable(warehouses),
      suppliers: List.unmodifiable(suppliers),
      accounts: List.unmodifiable(accounts),
      activeShiftsByAccount: Map.unmodifiable(activeShiftsByAccount),
    );
  }

  void updateShifts(Map<String, String> activeShiftsByAccount) {
    if (_cached != null) {
      _cached = InventoryEntryCatalogCacheData(
        warehouses: _cached!.warehouses,
        suppliers: _cached!.suppliers,
        accounts: _cached!.accounts,
        activeShiftsByAccount: Map.unmodifiable(activeShiftsByAccount),
        cachedAt: _cached!.cachedAt,
      );
    }
  }

  void clear() {
    _cached = null;
  }
}
