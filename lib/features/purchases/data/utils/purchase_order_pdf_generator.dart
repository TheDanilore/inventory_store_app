import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';

class PurchaseOrderPdfGenerator {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor accentColor = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor lightBgColor = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);

  static Future<Uint8List> buildPdfBytes({
    required PurchaseOrderModel po,
    required List<PurchaseOrderItemEntity> items,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');
    final code =
        '#OC-${po.id.substring(0, po.id.length >= 8 ? 8 : po.id.length).toUpperCase()}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // ── Header con Logotipo e Info de la Orden ─────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ORDEN DE COMPRA',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'INVENTORY STORE APP',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: lightBgColor,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderColor),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        code,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Fecha: ${dateFormat.format(po.createdAt.toLocal())}',
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(color: borderColor, thickness: 0.8),
            pw.SizedBox(height: 12),

            // ── Tarjetas de Información: Proveedor y Almacén ──────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBgColor,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PROVEEDOR',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: textMuted,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          po.supplierName,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        if (po.documentNumber != null &&
                            po.documentNumber!.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Doc: ${po.documentType} ${po.documentNumber}',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBgColor,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DESTINO & CONDICIONES',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: textMuted,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          po.warehouseName ?? 'Almacén Principal',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Estado: ${_getStatusLabel(po.status)} · Pago: ${_getPaymentStatusLabel(po.paymentStatus)}',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: textMuted,
                          ),
                        ),
                        if (po.dueDate != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Vence: ${DateFormat('dd/MM/yyyy', 'es').format(po.dueDate!)}',
                            style: const pw.TextStyle(
                              fontSize: 8.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ── Tabla de Ítems / Productos Solicitados ────────────────────────
            pw.Text(
              'DETALLE DE PRODUCTOS',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: primaryColor,
              ),
            ),
            pw.SizedBox(height: 6),

            if (items.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 16),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Text(
                  'No se registraron productos en esta orden (${po.itemCount} declarados).',
                  style: const pw.TextStyle(fontSize: 9.5, color: textMuted),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                headerDecoration: const pw.BoxDecoration(color: lightBgColor),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8.5,
                  color: primaryColor,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headers: [
                  '#',
                  'Descripción del Producto',
                  'Cant. Pedida',
                  'Cant. Recibida',
                  'Costo Unit.',
                  'Subtotal',
                ],
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                },
                data: List.generate(items.length, (index) {
                  final item = items[index];
                  final desc = [
                    item.productName ?? 'Producto',
                    if (item.variantAttrs.isNotEmpty &&
                        item.variantAttrs != 'Única' &&
                        item.variantAttrs.toLowerCase() != 'estándar')
                      item.variantAttrs,
                    if (item.sku != null && item.sku!.isNotEmpty)
                      'SKU: ${item.sku}',
                  ].join(' · ');

                  return [
                    '${index + 1}',
                    desc,
                    item.quantityOrdered.toStringAsFixed(0),
                    item.quantityReceived.toStringAsFixed(0),
                    'S/ ${item.unitCost.toStringAsFixed(2)}',
                    'S/ ${item.subtotal.toStringAsFixed(2)}',
                  ];
                }),
              ),
            pw.SizedBox(height: 14),

            // ── Resumen Financiero y Totales ─────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child:
                      po.notes != null && po.notes!.isNotEmpty
                          ? pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: lightBgColor,
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(color: borderColor),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'NOTAS:',
                                  style: pw.TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: textMuted,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  po.notes!,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ],
                            ),
                          )
                          : pw.SizedBox.shrink(),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBgColor,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildTotalRow(
                          'Subtotal:',
                          'S/ ${(po.totalAmount + po.discountAmount - po.taxAmount).toStringAsFixed(2)}',
                        ),
                        if (po.discountAmount > 0) ...[
                          pw.SizedBox(height: 3),
                          _buildTotalRow(
                            'Descuento:',
                            '- S/ ${po.discountAmount.toStringAsFixed(2)}',
                          ),
                        ],
                        if (po.taxAmount > 0) ...[
                          pw.SizedBox(height: 3),
                          _buildTotalRow(
                            'Impuestos:',
                            'S/ ${po.taxAmount.toStringAsFixed(2)}',
                          ),
                        ],
                        pw.SizedBox(height: 5),
                        pw.Divider(color: borderColor, thickness: 0.5),
                        pw.SizedBox(height: 3),
                        _buildTotalRow(
                          'TOTAL ORDEN:',
                          'S/ ${po.totalAmount.toStringAsFixed(2)}',
                          isBold: true,
                          fontSize: 11,
                        ),
                        pw.SizedBox(height: 3),
                        _buildTotalRow(
                          'Monto Pagado:',
                          'S/ ${po.amountPaid.toStringAsFixed(2)}',
                        ),
                        if (po.totalAmount - po.amountPaid > 0) ...[
                          pw.SizedBox(height: 3),
                          _buildTotalRow(
                            'Saldo Pendiente:',
                            'S/ ${(po.totalAmount - po.amountPaid).toStringAsFixed(2)}',
                            color: PdfColor.fromInt(0xFFDC2626),
                            isBold: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // ── Pie de Documento y Firmas ────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: borderColor),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Emitido por (Compras)',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: borderColor),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Conforme Proveedor',
                      style: const pw.TextStyle(
                        fontSize: 7.5,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTotalRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 8.5,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? (isBold ? primaryColor : textMuted),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? primaryColor,
          ),
        ),
      ],
    );
  }

  static String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pendiente';
      case 'PARTIAL':
        return 'Parcial';
      case 'RECEIVED':
        return 'Recibida';
      case 'CANCELLED':
        return 'Cancelada';
      default:
        return status;
    }
  }

  static String _getPaymentStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Pagado';
      case 'PARTIAL':
        return 'Pago Parcial';
      case 'UNPAID':
        return 'Por Pagar';
      default:
        return status;
    }
  }

  static Future<void> printPdf({
    required PurchaseOrderModel po,
    required List<PurchaseOrderItemEntity> items,
  }) async {
    final bytes = await buildPdfBytes(po: po, items: items);
    final shortCode =
        po.id.substring(0, po.id.length >= 8 ? 8 : po.id.length).toUpperCase();
    await Printing.layoutPdf(
      name: 'Orden_Compra_$shortCode',
      onLayout: (format) async => bytes,
    );
  }

  static Future<void> sharePdf({
    required PurchaseOrderModel po,
    required List<PurchaseOrderItemEntity> items,
  }) async {
    final bytes = await buildPdfBytes(po: po, items: items);
    final shortCode =
        po.id.substring(0, po.id.length >= 8 ? 8 : po.id.length).toUpperCase();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Orden_Compra_$shortCode.pdf',
    );
  }

  static Future<FileExportResult> savePdf({
    required PurchaseOrderModel po,
    required List<PurchaseOrderItemEntity> items,
  }) async {
    final bytes = await buildPdfBytes(po: po, items: items);
    final shortCode =
        po.id.substring(0, po.id.length >= 8 ? 8 : po.id.length).toUpperCase();
    final fileName = 'Orden_Compra_$shortCode';
    return FileExportService.save(
      fileName: fileName,
      bytes: bytes,
      extension: 'pdf',
      mimeType: MimeType.pdf,
      dialogTitle: 'Guardar Orden de Compra',
    );
  }

  static String buildWhatsAppText({
    required PurchaseOrderModel po,
    required List<PurchaseOrderItemEntity> items,
  }) {
    final shortCode =
        po.id.substring(0, po.id.length >= 8 ? 8 : po.id.length).toUpperCase();
    final dateFormat = DateFormat('dd/MM/yyyy', 'es');
    final buffer = StringBuffer();

    buffer.writeln('📋 *ORDEN DE COMPRA #OC-$shortCode*');
    buffer.writeln('🏢 *Proveedor:* ${po.supplierName}');
    buffer.writeln('📅 *Fecha:* ${dateFormat.format(po.createdAt.toLocal())}');
    if (po.dueDate != null) {
      buffer.writeln('⏳ *Vence:* ${dateFormat.format(po.dueDate!)}');
    }
    buffer.writeln('📍 *Almacén destino:* ${po.warehouseName ?? "Principal"}');
    buffer.writeln('🏷️ *Estado:* ${_getStatusLabel(po.status)}');
    buffer.writeln(
      '💳 *Condición de Pago:* ${_getPaymentStatusLabel(po.paymentStatus)}',
    );
    buffer.writeln('─────────────────');

    if (items.isNotEmpty) {
      buffer.writeln('📦 *PRODUCTOS SOLICITADOS:*');
      for (final item in items) {
        final name = item.productName ?? 'Item';
        final qty = item.quantityOrdered.toStringAsFixed(0);
        final cost = 'S/ ${item.unitCost.toStringAsFixed(2)}';
        final sub = 'S/ ${item.subtotal.toStringAsFixed(2)}';
        buffer.writeln(' • $qty x $name a $cost = $sub');
      }
      buffer.writeln('─────────────────');
    }

    buffer.writeln('💰 *TOTAL ORDEN:* S/ ${po.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('💵 *Pagado:* S/ ${po.amountPaid.toStringAsFixed(2)}');
    final pending = po.totalAmount - po.amountPaid;
    if (pending > 0) {
      buffer.writeln('⚠️ *Saldo Pendiente:* S/ ${pending.toStringAsFixed(2)}');
    }
    buffer.writeln('─────────────────');
    buffer.writeln('Favor confirmar recepción de la presente orden.');

    return buffer.toString();
  }
}
