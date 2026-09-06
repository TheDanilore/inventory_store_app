import 'dart:convert';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_repository.dart';

enum InventoryExportMode {
  consolidated,
  byWarehouse,
}

enum InventoryStockFilterOption {
  all,
  inStockOnly,
  lowStockOnly,
}

@injectable
class ExportInventoryExcelUseCase {
  final InventoryRepository _repository;

  ExportInventoryExcelUseCase(this._repository);

  Future<String> call({
    String? warehouseId,
    String? warehouseName,
    InventoryExportMode mode = InventoryExportMode.consolidated,
    InventoryStockFilterOption filter = InventoryStockFilterOption.all,
  }) async {
    final items = await _repository.getAllStockForExport(
      warehouseId: mode == InventoryExportMode.consolidated ? null : warehouseId,
    );

    // Filtrar según criterio
    final filteredItems = items.where((item) {
      if (filter == InventoryStockFilterOption.inStockOnly) {
        return item.stock > 0;
      }
      if (filter == InventoryStockFilterOption.lowStockOnly) {
        return item.stockControl && item.isLowStock;
      }
      return true;
    }).toList();

    final csvString = await compute(
      _generateInventoryCsvString,
      _ExportData(
        items: filteredItems,
        mode: mode,
        warehouseName: warehouseName ?? 'Todos los almacenes',
        isSpecificWarehouse: warehouseId != null && warehouseId.isNotEmpty,
      ),
    );

    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    final prefix = mode == InventoryExportMode.consolidated
        ? 'inventario_general_consolidado'
        : (warehouseId != null && warehouseId.isNotEmpty
            ? 'inventario_${warehouseName?.replaceAll(' ', '_').toLowerCase() ?? 'almacen'}'
            : 'inventario_por_almacen');

    final fileName = '${prefix}_$dateStr';

    final bytes = utf8.encode(csvString);

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );

    return '$fileName.csv';
  }
}

class _ExportData {
  final List<InventoryStockItem> items;
  final InventoryExportMode mode;
  final String warehouseName;
  final bool isSpecificWarehouse;

  _ExportData({
    required this.items,
    required this.mode,
    required this.warehouseName,
    required this.isSpecificWarehouse,
  });
}

String _generateInventoryCsvString(_ExportData data) {
  final buffer = StringBuffer();
  // Inyectar BOM UTF-8 para compatibilidad nativa con Microsoft Excel en Windows y Mac
  buffer.write('\uFEFF');

  if (data.mode == InventoryExportMode.consolidated) {
    // ── MODO 1: CONSOLIDADO GENERAL ──
    buffer.writeln(
      'Producto,Variante,SKU,Categoría,Tipo,P. Venta (S/),Costo Ref. (S/),Margen (%),Stock Consolidado,Estado Stock,Punto Reorden,Control Lotes',
    );

    for (final item in data.items) {
      final margin = item.salePrice > 0 && item.unitCost > 0
          ? (((item.salePrice - item.unitCost) / item.salePrice) * 100)
              .toStringAsFixed(1)
          : '0.0';

      final statusStr = item.stock <= 0
          ? 'Agotado'
          : (item.isLowStock ? 'Bajo Stock' : 'Normal');

      final row = [
        _escapeCsv(item.productName),
        _escapeCsv(item.attrsText),
        _escapeCsv(item.sku ?? 'Sin SKU'),
        _escapeCsv(item.category),
        item.productType == 'good' ? 'Bien/Físico' : 'Servicio/Digital',
        item.salePrice.toStringAsFixed(2),
        item.unitCost.toStringAsFixed(2),
        '$margin%',
        item.stock.toString(),
        statusStr,
        item.reorderPoint.toString(),
        item.usesBatches ? 'Sí' : 'No',
      ];
      buffer.writeln(row.join(','));
    }
  } else {
    // ── MODO 2: DESGLOSADO POR ALMACÉN Y LOTES ──
    buffer.writeln(
      'Producto,Variante,SKU,Categoría,Almacén,Stock en Almacén,Lote,F. Vencimiento,Proveedor,P. Venta (S/),Costo Unit. (S/),Valor Inventario (S/)',
    );

    for (final item in data.items) {
      if (item.batches.isEmpty) {
        // Variante sin lotes asignados o stock 0
        final row = [
          _escapeCsv(item.productName),
          _escapeCsv(item.attrsText),
          _escapeCsv(item.sku ?? 'Sin SKU'),
          _escapeCsv(item.category),
          data.isSpecificWarehouse
              ? _escapeCsv(data.warehouseName)
              : 'Sin almacén asignado',
          item.stock.toString(),
          'N/A',
          'N/A',
          'N/A',
          item.salePrice.toStringAsFixed(2),
          item.unitCost.toStringAsFixed(2),
          (item.stock * item.unitCost).toStringAsFixed(2),
        ];
        buffer.writeln(row.join(','));
      } else {
        for (final b in item.batches) {
          final totalVal = b.availableQuantity * item.unitCost;
          final row = [
            _escapeCsv(item.productName),
            _escapeCsv(item.attrsText),
            _escapeCsv(item.sku ?? 'Sin SKU'),
            _escapeCsv(item.category),
            _escapeCsv(b.warehouseName ?? data.warehouseName),
            b.availableQuantity.toString(),
            _escapeCsv(b.batchNumber),
            _escapeCsv(b.expiryDate ?? 'Sin fecha'),
            _escapeCsv(b.supplierName ?? 'Sin proveedor'),
            item.salePrice.toStringAsFixed(2),
            item.unitCost.toStringAsFixed(2),
            totalVal.toStringAsFixed(2),
          ];
          buffer.writeln(row.join(','));
        }
      }
    }
  }

  return buffer.toString();
}

String _escapeCsv(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
