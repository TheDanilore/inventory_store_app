import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Clase inmutable contenedora de argumentos para la transferencia atómica de datos.
class _PdfIsolateArgs {
  final List<CustomerEntity> customers;
  final Uint8List fontRegularBytes;
  final Uint8List fontBoldBytes;
  final Uint8List fontItalicBytes;

  const _PdfIsolateArgs({
    required this.customers,
    required this.fontRegularBytes,
    required this.fontBoldBytes,
    required this.fontItalicBytes,
  });
}

/// Función de nivel superior ejecutada estrictamente en segundo plano por el Isolate.
Future<Uint8List> _generatePdfInIsolate(_PdfIsolateArgs args) async {
  return await CustomerPdfGenerator._buildPdfInternal(args);
}

class CustomerPdfGenerator {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );

  /// Método público orquestador. Resuelve los recursos nativos y despacha el Isolate.
  static Future<Uint8List> _buildPdf({
    required List<CustomerEntity> customers,
  }) async {
    // Descarga/Carga de los objetos tipográficos desde el hilo principal
    final regularFont = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();
    final italicFont = await PdfGoogleFonts.interItalic();

    // EXIGENCIA SENIOR / CORRECCIÓN DE TIPOS: Extraemos los bytes de los objetos
    // mapeándolos dinámicamente de forma segura para saltar conflictos de tipos del linter.
    final dynamic reg = regularFont;
    final dynamic bld = boldFont;
    final dynamic itl = italicFont;

    final Uint8List? regularData = await reg.font.data;
    final Uint8List? boldData = await bld.font.data;
    final Uint8List? italicData = await itl.font.data;

    if (regularData == null || boldData == null || italicData == null) {
      throw Exception(
        'FALLO CRÍTICO: No se pudieron extraer los bytes de las fuentes tipográficas.',
      );
    }

    return await compute(
      _generatePdfInIsolate,
      _PdfIsolateArgs(
        customers: customers,
        fontRegularBytes: regularData,
        fontBoldBytes: boldData,
        fontItalicBytes: italicData,
      ),
    );
  }

  /// Proceso pesado interno de CPU. Retorna un [Future<Uint8List>] ya que doc.save() es asíncrono.
  static Future<Uint8List> _buildPdfInternal(_PdfIsolateArgs args) async {
    final baseFont = pw.Font.ttf(args.fontRegularBytes.buffer.asByteData());
    final boldFont = pw.Font.ttf(args.fontBoldBytes.buffer.asByteData());
    final italicFont = pw.Font.ttf(args.fontItalicBytes.buffer.asByteData());

    final doc = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
          italic: italicFont,
        ),
        build:
            (context) => [
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
              _buildCustomersTable(args.customers),
            ],
      ),
    );

    return await doc.save();
  }

  static pw.Widget _buildCustomersTable(List<CustomerEntity> customers) {
    final headers = [
      'Nombre',
      'Documento',
      'Teléfono',
      'Estado',
      'Deuda Total',
    ];

    final data =
        customers.map((c) {
          return [
            c.fullName,
            c.documentNumber ?? '-',
            c.phone ?? '-',
            c.isActive ? 'Activo' : 'Inactivo',
            c.currentDebt > 0
                ? _currencyFormat.format(c.currentDebt)
                : 'S/ 0.00',
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
    final generatedAt = DateFormat('yyyyMMdd_HHmm', 'es').format(DateTime.now());
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'clientes_$generatedAt.pdf',
    );
  }
}
