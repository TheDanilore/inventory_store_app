import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/widgets/account_statement/statement_item_model.dart';

/// Servicio de generación, maquetación vectorial y exportación de PDFs para Estados de Cuenta
class AccountStatementPdfService {
  Uint8List? _cachedPdfBytes;
  String? _cachedSignature;

  /// Genera los bytes del documento PDF A4 corporativo con caché en memoria
  Future<Uint8List> generatePdfBytes({
    required String businessName,
    required String businessTaxId,
    required String businessAddress,
    required String titularName,
    required bool isSupplier,
    required String currencySymbol,
    required double currentBalance,
    required double totalCharged,
    required double totalPaid,
    required List<StatementItem> items,
  }) async {
    final signature =
        '$titularName-$isSupplier-$currentBalance-$totalCharged-$totalPaid-${items.length}';

    if (_cachedPdfBytes != null && _cachedSignature == signature) {
      return _cachedPdfBytes!;
    }

    final pdf = pw.Document();
    final nowStr = DateFormat('dd/MM/yyyy HH:mm', 'es').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return [
            // Cabecera institucional
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName.isNotEmpty ? businessName : 'MI NEGOCIO',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if (businessTaxId.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'RUC: $businessTaxId',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    if (businessAddress.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        businessAddress,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.blueGrey800,
                      width: 1.2,
                    ),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'ESTADO DE CUENTA',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        isSupplier ? 'CRÉDITO PROVEEDOR' : 'CRÉDITO CLIENTE',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        nowStr,
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Tarjeta de Beneficiario y Resumen de Saldos
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Titular: $titularName',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tipo: ${isSupplier ? "Proveedor" : "Cliente"}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      _buildPdfKpi(
                        'Total Cargos',
                        '$currencySymbol ${totalCharged.toStringAsFixed(2)}',
                      ),
                      pw.SizedBox(width: 12),
                      _buildPdfKpi(
                        'Total Pagado',
                        '$currencySymbol ${totalPaid.toStringAsFixed(2)}',
                      ),
                      pw.SizedBox(width: 12),
                      _buildPdfKpi(
                        'Saldo Actual',
                        '$currencySymbol ${currentBalance.toStringAsFixed(2)}',
                        isHighlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Tabla de Movimientos
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(2.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.blueGrey800,
                  ),
                  children: [
                    _buildPdfCell('FECHA', isHeader: true),
                    _buildPdfCell(
                      'TIPO',
                      isHeader: true,
                      align: pw.TextAlign.center,
                    ),
                    _buildPdfCell(
                      'MONTO',
                      isHeader: true,
                      align: pw.TextAlign.right,
                    ),
                    _buildPdfCell('MÉTODO', isHeader: true),
                    _buildPdfCell('NOTAS', isHeader: true),
                  ],
                ),
                ...items.map((m) {
                  final dateStr =
                      m.date != null
                          ? DateFormat('dd/MM/yyyy HH:mm', 'es').format(m.date!)
                          : '-';
                  return pw.TableRow(
                    children: [
                      _buildPdfCell(dateStr),
                      _buildPdfCell(
                        m.isCharge ? 'CARGO' : 'ABONO',
                        align: pw.TextAlign.center,
                      ),
                      _buildPdfCell(
                        '$currencySymbol ${m.amount.toStringAsFixed(2)}',
                        align: pw.TextAlign.right,
                      ),
                      _buildPdfCell(m.method ?? '-'),
                      _buildPdfCell(m.notes ?? '-'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.Center(
              child: pw.Text(
                'Reporte de movimientos para uso administrativo y conciliación de créditos.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    _cachedPdfBytes = bytes;
    _cachedSignature = signature;
    return bytes;
  }

  /// Imprime el estado de cuenta a través del spooler del sistema operativo
  Future<void> printStatement({
    required Uint8List bytes,
    required String titularName,
  }) async {
    final cleanName = titularName.replaceAll(' ', '_');
    await Printing.layoutPdf(
      name: 'Estado_Cuenta_$cleanName',
      onLayout: (_) async => bytes,
    );
  }

  /// Guarda el estado de cuenta como archivo PDF en disco
  Future<FileExportResult> savePdfFile({
    required Uint8List bytes,
    required String titularName,
  }) async {
    try {
      final cleanName = titularName.replaceAll(' ', '_');
      return await FileExportService.save(
        fileName: 'Estado_Cuenta_$cleanName',
        bytes: bytes,
        extension: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (e, st) {
      LoggerService.e(
        'Error al exportar PDF de estado de cuenta',
        tag: 'STATEMENT_PDF_SERVICE',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  pw.Widget _buildPdfKpi(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: isHighlight ? PdfColors.red800 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }
}
