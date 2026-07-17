import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';

class CreditMovementsPdfGenerator {
  static Future<Uint8List> generatePdf({
    required String supplierName,
    required List<SupplierCreditMovementEntity> allMovements,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Estado de Cuenta',
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
            pw.Text(
              'Proveedor: $supplierName',
              style: pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Fecha',
                'Tipo',
                'Monto',
                'Método',
                'Usuario',
                'Notas',
              ],
              data:
                  allMovements.map((m) {
                    final dateStr =
                        m.createdAt != null
                            ? DateFormat('dd/MM/yy HH:mm').format(m.createdAt!)
                            : '-';
                    final typeStr = m.isCharge ? 'CARGO' : 'ABONO';
                    final amtStr = '\$${m.amount.toStringAsFixed(2)}';
                    return [
                      dateStr,
                      typeStr,
                      amtStr,
                      m.paymentMethod ?? '-',
                      m.createdByName ?? '-',
                      m.notes ?? '-',
                    ];
                  }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
