import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

class KardexPdfService {
  static Future<void> exportKardexToPdf(
    List<KardexMovementEntity> allMovements, {
    DateTime? startDate,
    DateTime? endDate,
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

            if (startDate != null && endDate != null)
              pw.Text(
                'Fechas: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
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
                      DateFormat('dd/MM/yy HH:mm').format(m.date.toLocal()),
                      m.type,
                      m.description,
                      m.reference,
                      m.balance.toString(),
                      '${m.quantity > 0 ? '+' : ''}${m.quantity}',
                      (m.balance).toString(),
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
