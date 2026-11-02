import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel_plus/excel_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';

/// Servicio de generación y exportación de plantillas y reportes de incidencias
class BulkImportReportService {
  /// Genera y descarga la plantilla canónica para importación de productos
  static Future<FileExportResult> downloadTemplate({
    bool asExcel = true,
  }) async {
    final rows = <List<dynamic>>[
      [
        'nombre',
        'marca',
        'categoria',
        'variante',
        'sku',
        'precio_compra',
        'precio_venta',
        'precio_mayor',
        'cantidad_mayor',
        'stock',
        'usa_lotes',
        'lote',
        'vencimiento',
        'componentes',
        'descripcion',
        'imagen_url',
      ],
      [
        'Paracetamol 500mg',
        'Genfar',
        'Analgésicos',
        '',
        'PAR-500',
        0.20,
        0.50,
        0.40,
        12,
        200,
        'si',
        'L2401',
        '2027-06-30',
        'Paracetamol',
        'Analgésico y antipirético',
        '',
      ],
      [
        'Paracetamol 500mg',
        'Genfar',
        'Analgésicos',
        '',
        'PAR-500',
        0.20,
        0.50,
        0.40,
        12,
        150,
        'si',
        'L2402',
        '2027-12-31',
        'Paracetamol',
        '',
        '',
      ],
      [
        'Ibuprofeno',
        'MK',
        'Antiinflamatorios',
        '400mg',
        'IBU-400',
        0.30,
        0.80,
        0.60,
        12,
        100,
        'si',
        'L9901',
        '2027-03-31',
        'Ibuprofeno',
        '',
        '',
      ],
      [
        'Ibuprofeno',
        'MK',
        'Antiinflamatorios',
        '600mg',
        'IBU-600',
        0.45,
        1.20,
        0.95,
        12,
        60,
        'si',
        'L9902',
        '2027-03-31',
        'Ibuprofeno',
        '',
        '',
      ],
      [
        'Alcohol medicinal 70%',
        'Alkofarma',
        'Insumos',
        '',
        'ALC-70',
        3.00,
        5.00,
        4.20,
        12,
        40,
        'no',
        '',
        '',
        'Alcohol etílico',
        '',
        '',
      ],
    ];

    if (asExcel) {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Plantilla Productos');
      final sheet = excel['Plantilla Productos'];

      for (final row in rows) {
        final cellRow = <CellValue?>[];
        for (final cell in row) {
          if (cell is int) {
            cellRow.add(IntCellValue(cell));
          } else if (cell is double) {
            cellRow.add(DoubleCellValue(cell));
          } else {
            cellRow.add(TextCellValue(cell.toString()));
          }
        }
        sheet.appendRow(cellRow);
      }

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        return FileExportService.save(
          fileName: 'plantilla_productos',
          bytes: Uint8List.fromList(fileBytes),
          extension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      }
      return const FileExportResult.failed('Error al codificar archivo Excel');
    } else {
      final csv = Csv().encode(rows);
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      return FileExportService.save(
        fileName: 'plantilla_productos',
        bytes: bytes,
        extension: 'csv',
        mimeType: MimeType.csv,
      );
    }
  }

  /// Genera y descarga el reporte de incidencias (errores y advertencias)
  static Future<FileExportResult> downloadIssuesReport({
    required List<ImportRow> rows,
    required List<String> fileErrors,
    bool asExcel = true,
  }) async {
    final reportRows = <List<dynamic>>[
      ['fila', 'columna', 'tipo', 'mensaje'],
      for (final r in rows)
        for (final i in r.issues)
          [
            i.line,
            i.column,
            i.severity == IssueSeverity.error ? 'error' : 'advertencia',
            i.message,
          ],
      for (final e in fileErrors) ['-', '-', 'error', e],
    ];

    if (asExcel) {
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Reporte Incidencias');
      final sheet = excel['Reporte Incidencias'];

      for (final row in reportRows) {
        final cellRow = <CellValue?>[];
        for (final cell in row) {
          if (cell is int) {
            cellRow.add(IntCellValue(cell));
          } else {
            cellRow.add(TextCellValue(cell.toString()));
          }
        }
        sheet.appendRow(cellRow);
      }

      final fileBytes = excel.encode();
      if (fileBytes != null) {
        return FileExportService.save(
          fileName: 'reporte_importacion',
          bytes: Uint8List.fromList(fileBytes),
          extension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      }
      return const FileExportResult.failed('Error al codificar archivo Excel');
    } else {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(Csv().encode(reportRows)),
      ]);
      return FileExportService.save(
        fileName: 'reporte_importacion',
        bytes: bytes,
        extension: 'csv',
        mimeType: MimeType.csv,
      );
    }
  }
}
