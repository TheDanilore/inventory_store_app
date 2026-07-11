import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryExitsPdfGenerator {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
    customPattern: '¤#,##0.00',
  );

  static Future<Uint8List> _buildPdf({
    required List<InventoryExitModel> exits,
    required DateTimeRange? dateRange,
  }) async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final italicFont = await PdfGoogleFonts.notoSansItalic();

    final doc = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    double totalGeneralCost = exits.fold(
      0.0,
      (sum, exit) => sum + exit.totalCost,
    );

    String dateText = 'Rango: Histórico Completo';
    if (dateRange != null) {
      final start = DateFormat('dd/MM/yyyy').format(dateRange.start);
      final end = DateFormat('dd/MM/yyyy').format(dateRange.end);
      dateText = 'Rango: $start - $end';
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont,
          italic: italicFont,
        ),
        build:
            (context) => [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Reporte de Salidas de Inventario',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        dateText,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Generado: $generatedAt',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.red200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Costo Total Perdido',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                        pw.Text(
                          _currencyFormat.format(totalGeneralCost),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), // Fecha
                  1: const pw.FlexColumnWidth(1.5), // Motivo
                  2: const pw.FlexColumnWidth(1.5), // Almacén
                  3: const pw.FlexColumnWidth(2.5), // Notas
                  4: const pw.FlexColumnWidth(0.8), // Ítems
                  5: const pw.FlexColumnWidth(1.2), // Costo
                },
                children: [
                  // Encabezados
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children:
                        [
                              'Fecha',
                              'Motivo',
                              'Almacén',
                              'Notas',
                              'Ítems',
                              'Costo Total',
                            ]
                            .map(
                              (text) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  text,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  // Datos
                  ...exits.map((exit) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            exit.createdAt != null
                                ? DateFormat(
                                  'dd/MM/yy HH:mm',
                                ).format(exit.createdAt!.toLocal())
                                : '',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            exit.reason ?? 'N/A',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            exit.warehouseName ?? 'N/A',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            exit.notes ?? '',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            exit.itemCount.toString(),
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            _currencyFormat.format(exit.totalCost),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.red800,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
      ),
    );

    return doc.save();
  }

  static Future<void> printReport({
    required List<InventoryExitModel> exits,
    required DateTimeRange? dateRange,
  }) async {
    final bytes = await _buildPdf(exits: exits, dateRange: dateRange);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name:
          'Reporte_Salidas_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static Future<void> shareReport({
    required List<InventoryExitModel> exits,
    required DateTimeRange? dateRange,
  }) async {
    final bytes = await _buildPdf(exits: exits, dateRange: dateRange);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'Reporte_Salidas_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
