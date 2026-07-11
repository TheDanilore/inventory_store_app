import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventory_store_app/features/inventory/data/models/kardex_movement_model.dart';

class KardexPdfService {
  static Future<void> exportKardexToPdf(
    List<KardexMovementModel> allMovements, {
    DateTimeRange? dateRange,
    required String typeFilter,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Reporte de Kardex',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            if (dateRange != null)
              pw.Text(
                'Fechas: ${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}',
              ),

            pw.Text('Tipo de filtro: ${_getTypeFilterName(typeFilter)}'),
            pw.SizedBox(height: 20),

            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: [
                'Fecha',
                'Tipo',
                'Producto / SKU',
                'Almacén',
                'Stock Ant.',
                'Cant.',
                'Nuevo Stock',
              ],
              data:
                  allMovements.map((m) {
                    return [
                      m.movement.createdAt != null
                          ? DateFormat(
                            'dd/MM/yy HH:mm',
                          ).format(m.movement.createdAt!.toLocal())
                          : '',
                      m.movementType,
                      '${m.productName} ${m.attrsText != 'Única' ? '(${m.attrsText})' : ''} ${m.sku != null ? '\nSKU: ${m.sku}' : ''}',
                      m.warehouseName,
                      m.movement.previousStock.toString(),
                      '${(m.isEntry || m.isReturn) ? '+' : ''}${m.movement.quantity}',
                      m.movement.newStock.toString(),
                    ];
                  }).toList(),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Kardex_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  static String _getTypeFilterName(String typeFilter) {
    switch (typeFilter) {
      case 'ENTRY':
        return 'Ingresos';
      case 'EXIT':
        return 'Salidas';
      case 'SALE':
        return 'Ventas';
      case 'RETURN':
        return 'Devoluciones';
      default:
        return 'Todos los movimientos';
    }
  }
}
