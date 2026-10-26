import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:file_saver/file_saver.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';

class OrderPdfGenerator {
  /// Helper para convertir cualquier fecha de UTC a Hora de Perú (UTC-5)
  static DateTime _toPeruTime(DateTime date) {
    return date.toUtc().subtract(const Duration(hours: 5));
  }

  // --- Helpers de traducción para el ticket ---
  static String _translateStatus(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Completado';
      case 'PENDING':
        return 'Pendiente';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  static String _translatePaymentStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Pagado';
      case 'PENDING':
        return 'Pendiente';
      case 'PARTIAL':
        return 'Parcial';
      default:
        return status;
    }
  }

  static Future<Uint8List> buildPdfBytes(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final pdf = pw.Document();

    final peruTime = _toPeruTime(order.createdAt ?? DateTime.now());
    final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'es').format(peruTime);
    final currencySymbol = order.currencySymbol;

    // 2. Construir el diseño del PDF (Formato Ticket/Rollo)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- CABECERA (Info del Negocio) ---
              pw.Center(
                child: pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(taxId, style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  address,
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (phone.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    phone,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // --- INFO DEL COMPROBANTE ---
              pw.Text(
                '${order.documentType == "FACTURA" ? "FACTURA ELECTRÓNICA" : (order.documentType == "BOLETA" ? "BOLETA ELECTRÓNICA" : "NOTA DE VENTA")}: ${order.displayReceiptNumber}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
              pw.Text(
                'FECHA: $dateStr',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'CLIENTE: ${(order.customerName).isNotEmpty ? (order.customerName) : 'Cliente Mostrador'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (order.customerDocumentNumber != null &&
                  order.customerDocumentNumber!.isNotEmpty)
                pw.Text(
                  '${order.customerDocumentType ?? "DOC"}: ${order.customerDocumentNumber}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (order.customerAddress != null &&
                  order.customerAddress!.isNotEmpty)
                pw.Text(
                  'DIRECCIÓN: ${order.customerAddress}',
                  style: const pw.TextStyle(fontSize: 9.5),
                ),
              pw.Text(
                'PAGO: ${order.paymentMethod}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (order.paymentReference != null &&
                  order.paymentReference!.isNotEmpty)
                pw.Text(
                  'REF. OPERACIÓN: ${order.paymentReference}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if (order.paymentMethod.toUpperCase().contains('CREDIT') ||
                  order.paymentStatus.toUpperCase() == 'PENDING' ||
                  order.paymentStatus.toUpperCase() == 'PARTIAL')
                pw.Text(
                  'CONDICIÓN: ${order.paymentStatus.toUpperCase() == "PARTIAL" ? "CRÉDITO (PAGO PARCIAL)" : "AL CRÉDITO"}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // --- CABECERA TABLA DE ITEMS ---
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3, // Más espacio para el nombre
                    child: pw.Text(
                      'CANT x DESCRIPCIÓN',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'IMPORTE',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),

              // --- LISTA DE ITEMS ---
              ..._buildItemList(items, currencySymbol: currencySymbol),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // --- TOTALES ---
              // Subtotal (Sumando los subtotales de los items)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'OP. GRAVADA:',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '$currencySymbol ${(order.subtotalAmount > 0 ? order.subtotalAmount : double.parse((order.totalAmount / 1.18).toStringAsFixed(2))).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'I.G.V. (18%):',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '$currencySymbol ${(order.taxAmount > 0 ? order.taxAmount : double.parse((order.totalAmount - (order.totalAmount / 1.18)).toStringAsFixed(2))).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),

              if (order.discountAmount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'DESCUENTO:',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      '- $currencySymbol ${order.discountAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],

              if (order.pointsUsed > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'PUNTOS CANJEADOS:',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      '- ${order.pointsUsed} pts',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],

              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL FINAL:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  pw.Text(
                    '$currencySymbol ${order.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text(
                  '¡Gracias por su compra!',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    // hasta antes de Printing.layoutPdf()

    return pdf.save();
  }

  static pw.Widget _buildA4Cell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static Future<Uint8List> buildA4PdfBytes(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final pdf = pw.Document();
    final peruTime = _toPeruTime(order.createdAt ?? DateTime.now());
    final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'es').format(peruTime);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabecera A4 (Empresa a la izquierda, Recuadro de Comprobante a la derecha)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
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
                        pw.SizedBox(height: 6),
                        if (taxId.isNotEmpty)
                          pw.Text(
                            'RUC / ID Fiscal: $taxId',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        if (address.isNotEmpty)
                          pw.Text(
                            'Dirección: $address',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        if (phone.isNotEmpty)
                          pw.Text(
                            'Teléfono: $phone',
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Container(
                    width: 210,
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 14,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.blueGrey800,
                        width: 1.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      children: [
                        if (taxId.isNotEmpty)
                          pw.Text(
                            'R.U.C. $taxId',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          order.documentType == "FACTURA"
                              ? "FACTURA ELECTRÓNICA"
                              : (order.documentType == "BOLETA"
                                  ? "BOLETA ELECTRÓNICA"
                                  : "NOTA DE VENTA"),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey800,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'N° ${order.displayReceiptNumber}',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Datos del cliente
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
                          'Cliente: ${order.displayCustomerName}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Medio de Pago: ${order.paymentMethod}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Fecha de Emisión: $dateStr',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Estado: ${_translateStatus(order.status)} (${_translatePaymentStatus(order.paymentStatus)})',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Tabla de productos
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                    ),
                    children: [
                      _buildA4Cell(
                        'CANT.',
                        isHeader: true,
                        align: pw.TextAlign.center,
                      ),
                      _buildA4Cell('DESCRIPCIÓN', isHeader: true),
                      _buildA4Cell(
                        'P. UNIT.',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                      _buildA4Cell(
                        'IMPORTE',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    String displayName = item.productName ?? 'Producto';
                    final vLabel = item.variantLabel.trim();
                    if (item.hasVariantAttributes &&
                        vLabel.isNotEmpty &&
                        vLabel != '()' &&
                        vLabel.toLowerCase() != 'variante estándar' &&
                        vLabel.toLowerCase() != 'estándar' &&
                        vLabel.toLowerCase() != 'única') {
                      displayName = '$displayName ($vLabel)';
                    }
                    return pw.TableRow(
                      children: [
                        _buildA4Cell(
                          '${item.quantity}',
                          align: pw.TextAlign.center,
                        ),
                        _buildA4Cell(displayName),
                        _buildA4Cell(
                          '${order.currencySymbol} ${item.appliedPrice.toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                        ),
                        _buildA4Cell(
                          '${order.currencySymbol} ${item.subtotal.toStringAsFixed(2)}',
                          align: pw.TextAlign.right,
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 14),

              // Totales a la derecha
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.SizedBox(
                    width: 220,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Subtotal:',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                            pw.Text(
                              '${order.currencySymbol} ${items.fold<double>(0, (s, i) => s + i.subtotal).toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        if (order.discountAmount > 0) ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Descuento:',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                              pw.Text(
                                '- ${order.currencySymbol} ${order.discountAmount.toStringAsFixed(2)}',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                        if (order.pointsUsed > 0) ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Puntos Canjeados:',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                              pw.Text(
                                '- ${order.pointsUsed} pts',
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Divider(color: PdfColors.grey400),
                        ),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'TOTAL A PAGAR:',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blueGrey900,
                              ),
                            ),
                            pw.Text(
                              '${order.currencySymbol} ${order.totalAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blueGrey900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Center(
                child: pw.Text(
                  'Comprobante emitido como constancia de venta · ¡Gracias por su preferencia!',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String buildWhatsAppText(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
  }) {
    final shortId =
        order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id;
    final peruTime = _toPeruTime(order.createdAt ?? DateTime.now());
    final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'es').format(peruTime);
    final buffer = StringBuffer();
    buffer.writeln('🧾 *COMPROBANTE DE COMPRA*');
    buffer.writeln(
      '🏪 *${businessName.isNotEmpty ? businessName : "DANILORE"}*',
    );
    if (taxId.isNotEmpty) buffer.writeln('📄 RUC: $taxId');
    buffer.writeln('--------------------------------');
    buffer.writeln('🔖 *N° Pedido:* #$shortId');
    buffer.writeln('📅 *Fecha:* $dateStr');
    buffer.writeln('👤 *Cliente:* ${order.displayCustomerName}');
    buffer.writeln('💳 *Pago:* ${order.paymentMethod}');
    buffer.writeln('--------------------------------');
    buffer.writeln('🛍️ *DETALLE DE PRODUCTOS:*');
    for (final item in items) {
      String name = item.productName ?? 'Producto';
      if (item.hasVariantAttributes && item.variantLabel.isNotEmpty) {
        name += ' (${item.variantLabel})';
      }
      buffer.writeln(
        '• ${item.quantity}x $name - ${order.currencySymbol} ${item.subtotal.toStringAsFixed(2)}',
      );
    }
    buffer.writeln('--------------------------------');
    if (order.discountAmount > 0) {
      buffer.writeln(
        '📉 Descuento: - ${order.currencySymbol} ${order.discountAmount.toStringAsFixed(2)}',
      );
    }
    buffer.writeln(
      '💰 *TOTAL: ${order.currencySymbol} ${order.totalAmount.toStringAsFixed(2)}*',
    );
    buffer.writeln('--------------------------------');
    buffer.writeln('¡Muchas gracias por su preferencia! ✨');
    return buffer.toString();
  }

  static Future<void> printA4(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final bytes = await buildA4PdfBytes(
      order,
      items: items,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Comprobante_A4_${order.id.substring(0, 8)}.pdf',
    );
  }

  static Future<void> shareA4(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final bytes = await buildA4PdfBytes(
      order,
      items: items,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
    );

    final safeNumber = order.displayReceiptNumber.replaceAll('/', '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Comprobante_A4_$safeNumber.pdf',
    );
  }

  static Future<void> saveA4(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final bytes = await buildA4PdfBytes(
      order,
      items: items,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
    );

    await FileExportService.save(
      fileName: 'Comprobante_A4_${order.id.substring(0, 8)}',
      bytes: bytes,
      extension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> printTicket(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final bytes = await buildPdfBytes(
      order,
      items: items,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Pedido_${order.id.substring(0, 8)}.pdf',
    );
  }

  static Future<void> shareTicket(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final bytes = await buildPdfBytes(
      order,
      items: items,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
    );

    final safeNumber = order.displayReceiptNumber.replaceAll('/', '_');
    await Printing.sharePdf(bytes: bytes, filename: 'Ticket_$safeNumber.pdf');
  }

  static Future<void> saveTicket(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final bytes = await buildPdfBytes(
      order,
      items: items,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
    );

    await FileExportService.save(
      fileName: 'Pedido_${order.id.substring(0, 8)}',
      bytes: bytes,
      extension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> saveTicketAs(
    OrderEntity order, {
    required List<OrderItemEntity> items,
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    final bytes = await buildPdfBytes(
      order,
      items: items,
      businessName: businessName,
      taxId: taxId,
      address: address,
      phone: phone,
    );

    await FileSaver.instance.saveAs(
      name: 'Pedido_${order.id.substring(0, 8)}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static List<pw.Widget> _buildItemList(
    List<OrderItemEntity> items, {
    String currencySymbol = 'S/',
  }) {
    List<pw.Widget> widgets = [];
    for (final item in items) {
      String displayName = item.productName ?? 'Producto';
      final String vLabel = item.variantLabel.trim();

      final bool hasRealVariant =
          item.hasVariantAttributes &&
          vLabel.isNotEmpty &&
          vLabel != '()' &&
          vLabel.toLowerCase() != 'variante estándar' &&
          vLabel.toLowerCase() != 'estándar' &&
          vLabel.toLowerCase() != 'única';

      if (hasRealVariant) {
        displayName = '$displayName - $vLabel';
      }

      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  '${item.quantity} x $displayName',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text(
                  '$currencySymbol ${item.subtotal.toStringAsFixed(2)}',
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}
