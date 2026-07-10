import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class _PdfIsolateArgs {
  final List<CustomerEntity> customers;
  _PdfIsolateArgs(this.customers);
}

Future<Uint8List> _generatePdfInIsolate(_PdfIsolateArgs args) async {
  return await CustomerPdfGenerator._buildPdfInternal(args.customers);
}

class CustomerPdfGenerator {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );

  static Future<Uint8List> _buildPdf({
    required List<CustomerEntity> customers,
  }) async {
    return await compute(_generatePdfInIsolate, _PdfIsolateArgs(customers));
  }

  static Future<Uint8List> _buildPdfInternal(
      List<CustomerEntity> customers) async {
    final baseFont = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();
    final italicFont = await PdfGoogleFonts.interItalic();

    final doc = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
          italic: italicFont,
        ),
        build: (context) => [
          pw.Text(
            'Reporte de Clientes',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Generado: $generatedAt'),
          pw.SizedBox(height: 16),
          _buildCustomersTable(customers),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildCustomersTable(List<CustomerEntity> customers) {
    final headers = [
      'Nombre',
      'Documento',
      'Teléfono',
      'Estado',
      'Deuda Total'
    ];

    final data = customers.map((c) {
      return [
        c.fullName,
        c.documentNumber ?? '-',
        c.phone ?? '-',
        c.isActive ? 'Activo' : 'Inactivo',
        c.currentDebt > 0 ? _currencyFormat.format(c.currentDebt) : 'S/ 0.00',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF1976D2),
      ),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF3F4F6),
      ),
    );
  }

  static Future<void> shareOrPrintPdf(List<CustomerEntity> customers) async {
    final pdfBytes = await _buildPdf(customers: customers);
    final generatedAt = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'clientes_$generatedAt.pdf',
    );
  }
}
