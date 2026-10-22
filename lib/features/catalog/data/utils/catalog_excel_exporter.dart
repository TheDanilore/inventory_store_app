import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

class CatalogExcelExporter {
  /// Exporta el listado de productos a un archivo Excel (.xlsx) con formato tabular.
  static Future<FileExportResult> exportToExcel(
    List<ProductEntity> products,
  ) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Catálogo');
    final sheet = excel['Catálogo'];

    // Cabeceras
    sheet.appendRow([
      TextCellValue('Producto / Nombre'),
      TextCellValue('Marca'),
      TextCellValue('Categoría'),
      TextCellValue('Variante / Presentación'),
      TextCellValue('SKU'),
      TextCellValue('Código de Barras'),
      TextCellValue('Costo (S/)'),
      TextCellValue('Precio Venta (S/)'),
      TextCellValue('Precio Mayorista (S/)'),
      TextCellValue('Cant. Mín. Mayorista'),
      TextCellValue('Stock Total'),
      TextCellValue('Punto Reorden'),
      TextCellValue('Control Stock'),
      TextCellValue('Maneja Lotes'),
      TextCellValue('Estado'),
    ]);

    // Filas de productos y variantes
    for (final p in products) {
      if (p.productVariants.isNotEmpty) {
        for (final v in p.productVariants) {
          sheet.appendRow([
            TextCellValue(p.name),
            TextCellValue(p.brandName ?? ''),
            TextCellValue(p.categoryName ?? ''),
            TextCellValue(v.label.isNotEmpty ? v.label : 'Estándar'),
            TextCellValue(v.sku ?? ''),
            TextCellValue(v.barcode ?? ''),
            DoubleCellValue(v.unitCost ?? 0.0),
            DoubleCellValue(v.salePrice ?? 0.0),
            DoubleCellValue(v.wholesalePrice ?? 0.0),
            IntCellValue(v.wholesaleMinQuantity ?? 0),
            IntCellValue(p.totalStock),
            IntCellValue(v.reorderPoint),
            TextCellValue(p.stockControl ? 'Sí' : 'No'),
            TextCellValue(p.usesBatches ? 'Sí' : 'No'),
            TextCellValue(v.isActive && p.isActive ? 'Activo' : 'Inactivo'),
          ]);
        }
      } else {
        sheet.appendRow([
          TextCellValue(p.name),
          TextCellValue(p.brandName ?? ''),
          TextCellValue(p.categoryName ?? ''),
          TextCellValue('Estándar'),
          TextCellValue(''),
          TextCellValue(''),
          DoubleCellValue(0.0),
          DoubleCellValue(p.displaySalePrice ?? 0.0),
          DoubleCellValue(0.0),
          IntCellValue(0),
          IntCellValue(p.totalStock),
          IntCellValue(0),
          TextCellValue(p.stockControl ? 'Sí' : 'No'),
          TextCellValue(p.usesBatches ? 'Sí' : 'No'),
          TextCellValue(p.isActive ? 'Activo' : 'Inactivo'),
        ]);
      }
    }

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('No se pudo generar el archivo Excel.');
    }

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'catalogo_productos_$dateStr';

    return FileExportService.save(
      fileName: fileName,
      bytes: Uint8List.fromList(fileBytes),
      extension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  /// Exporta el listado de productos a un archivo CSV estándar (con BOM UTF-8).
  static Future<FileExportResult> exportToCsv(
    List<ProductEntity> products,
  ) async {
    final rows = <List<dynamic>>[
      [
        'Producto / Nombre',
        'Marca',
        'Categoría',
        'Variante / Presentación',
        'SKU',
        'Código de Barras',
        'Costo (S/)',
        'Precio Venta (S/)',
        'Precio Mayorista (S/)',
        'Cant. Mín. Mayorista',
        'Stock Total',
        'Punto Reorden',
        'Control Stock',
        'Maneja Lotes',
        'Estado',
      ],
    ];

    for (final p in products) {
      if (p.productVariants.isNotEmpty) {
        for (final v in p.productVariants) {
          rows.add([
            p.name,
            p.brandName ?? '',
            p.categoryName ?? '',
            v.label.isNotEmpty ? v.label : 'Estándar',
            v.sku ?? '',
            v.barcode ?? '',
            (v.unitCost ?? 0.0).toStringAsFixed(2),
            (v.salePrice ?? 0.0).toStringAsFixed(2),
            (v.wholesalePrice ?? 0.0).toStringAsFixed(2),
            v.wholesaleMinQuantity ?? 0,
            p.totalStock,
            v.reorderPoint,
            p.stockControl ? 'Sí' : 'No',
            p.usesBatches ? 'Sí' : 'No',
            v.isActive && p.isActive ? 'Activo' : 'Inactivo',
          ]);
        }
      } else {
        rows.add([
          p.name,
          p.brandName ?? '',
          p.categoryName ?? '',
          'Estándar',
          '',
          '',
          '0.00',
          (p.displaySalePrice ?? 0.0).toStringAsFixed(2),
          '0.00',
          0,
          p.totalStock,
          0,
          p.stockControl ? 'Sí' : 'No',
          p.usesBatches ? 'Sí' : 'No',
          p.isActive ? 'Activo' : 'Inactivo',
        ]);
      }
    }

    final csvString = Csv().encode(rows);
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(csvString),
    ]);

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'catalogo_productos_$dateStr';

    return FileExportService.save(
      fileName: fileName,
      bytes: bytes,
      extension: 'csv',
      mimeType: MimeType.csv,
    );
  }
}
