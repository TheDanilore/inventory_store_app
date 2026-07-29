import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:file_saver/file_saver.dart';

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

  static Future<Uint8List> _buildPdf(
    OrderEntity order, {
    required List<OrderItemEntity> items,
  }) async {
    final pdf = pw.Document();

    // 1. Obtener la información del negocio (Síncrono/Asíncrono según prefieras)
    // Aquí hacemos una consulta rápida a 'business_info' (asumiendo que hay 1 fila)
    String businessName = 'MI NEGOCIO';
    String taxId = 'RUC: 00000000000';
    String address = 'Dirección no registrada';
    String phone = '';

    try {
      final supabase = Supabase.instance.client;
      final info =
          await supabase.from('business_info').select().limit(1).maybeSingle();

      if (info != null) {
        businessName = info['business_name'] ?? businessName;
        taxId = info['tax_id'] != null ? 'RUC: ${info['tax_id']}' : taxId;
        address = info['address'] ?? address;
        phone = info['phone'] != null ? 'Tel: ${info['phone']}' : phone;
      }
    } catch (_) {
      // Ignorar, usará valores por defecto
    }

    final peruTime = _toPeruTime(order.createdAt ?? DateTime.now());
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(peruTime);

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

              // --- INFO DEL PEDIDO ---
              pw.Text(
                'TICKET: #${order.id.substring(0, 8).toUpperCase()}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'FECHA: $dateStr',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'ESTADO: ${_translateStatus(order.status)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'CLIENTE: ${(order.customerName).isNotEmpty ? (order.customerName) : 'Cliente Mostrador'}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'PAGO: ${order.paymentMethod}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'ESTADO PAGO: ${_translatePaymentStatus(order.paymentStatus)}',
                style: const pw.TextStyle(fontSize: 10),
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
              ..._buildItemList(items),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // --- TOTALES ---
              // Subtotal (Sumando los subtotales de los items)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SUBTOTAL:', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text(
                    'S/ ${items.fold<double>(0, (s, i) => s + i.subtotal).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 11),
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
                      '- S/ ${order.discountAmount.toStringAsFixed(2)}',
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
                    'S/ ${order.totalAmount.toStringAsFixed(2)}',
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

  static Future<void> printTicket(
    OrderEntity order, {
    required List<OrderItemEntity> items,
  }) async {
    final bytes = await _buildPdf(order, items: items);

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Pedido_${order.id.substring(0, 8)}.pdf',
    );
  }

  static Future<void> shareTicket(
    OrderEntity order, {
    required List<OrderItemEntity> items,
  }) async {
    final bytes = await _buildPdf(order, items: items);

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Pedido_${order.id.substring(0, 8)}.pdf',
    );
  }

  static Future<void> saveTicket(
    OrderEntity order, {
    required List<OrderItemEntity> items,
  }) async {
    final bytes = await _buildPdf(order, items: items);

    await FileSaver.instance.saveFile(
      name: 'Pedido_${order.id.substring(0, 8)}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<void> saveTicketAs(
    OrderEntity order, {
    required List<OrderItemEntity> items,
  }) async {
    final bytes = await _buildPdf(order, items: items);

    await FileSaver.instance.saveAs(
      name: 'Pedido_${order.id.substring(0, 8)}',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static List<pw.Widget> _buildItemList(List<OrderItemEntity> items) {
    List<pw.Widget> widgets = [];
    for (final item in items) {
      // 1. Construir el nombre del producto limpio
      String displayName = item.productName ?? 'Producto';
      final String vLabel = item.variantLabel.trim();
      final String vLabelLower = vLabel.toLowerCase();

      // 2. Filtro robusto: ignorar si contiene "unica", "única", "default" o está vacío
      bool hasRealVariant =
          vLabel.isNotEmpty &&
          !vLabelLower.contains('default') &&
          !vLabelLower.contains('única') &&
          !vLabelLower.contains('unica') &&
          !vLabelLower.contains('estándar') &&
          !vLabelLower.contains('estandar') &&
          vLabel != '()';

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
                  'S/ ${item.subtotal.toStringAsFixed(2)}',
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
