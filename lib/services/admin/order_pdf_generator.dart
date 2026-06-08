import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/models/order_item_model.dart';

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

  static Future<void> generateTicket(
    OrderModel order, {
    List<OrderItemModel>? items,
  }) async {
    // 1. Obtener los items si no se pasaron por parámetro
    List<OrderItemModel> orderItems = items ?? [];

    if (orderItems.isEmpty) {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('order_items')
          .select('''
            id, order_id, product_id, variant_id, quantity, unit_cost,
            applied_price, net_profit, kardex_registered, created_at,
            products ( name ),
            product_variants ( attributes, sku )
          ''')
          .eq('order_id', order.id);

      orderItems =
          (response as List)
              .map(
                (row) =>
                    OrderItemModel.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList();
    }

    // Calculamos el subtotal sumando todos los items
    final double subtotalItems = orderItems.fold<double>(
      0.0,
      (sum, item) => sum + item.subtotal,
    );

    // 2. Configurar el documento PDF y Fechas
    final pdf = pw.Document();

    final rawDate = order.createdAt ?? DateTime.now();
    final peruDate = _toPeruTime(rawDate);
    final dateString = DateFormat('dd/MM/yyyy HH:mm').format(peruDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABECERA
              pw.Center(
                child: pw.Text(
                  'COMPROBANTE DE PEDIDO',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('ID Pedido: ${order.id.substring(0, 8).toUpperCase()}'),
              pw.Text('Fecha: $dateString'),
              pw.Text('Cliente: ${order.displayCustomerName}'),

              // Aplicamos las traducciones aquí
              pw.Text('Estado: ${_translateStatus(order.status)}'),
              pw.Text('Método Pago: ${order.paymentMethod}'),
              pw.Text(
                'Estado de Pago: ${_translatePaymentStatus(order.paymentStatus)}',
              ),

              pw.Text(
                'Monto Pagado: S/ ${order.amountPaid.toStringAsFixed(2)}',
              ),

              if (order.dueDate != null)
                pw.Text(
                  'Vencimiento: ${DateFormat('dd/MM/yyyy').format(order.dueDate!.toLocal())}',
                ),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // ITEMS
              pw.Text(
                'CANT  DESCRIPCION      TOTAL',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 5),
              ...orderItems.map((item) {
                final itemName =
                    item.variantDisplayName ?? item.productName ?? 'Producto';
                final subtotal = item.subtotal.toStringAsFixed(2);

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 28,
                        child: pw.Text(
                          '${item.quantity}x',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          itemName,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.SizedBox(
                        width: 50,
                        child: pw.Text(
                          'S/ $subtotal',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // TOTALES
              // Mostrar Subtotal solo si se aplicó algún tipo de descuento
              if (order.discountAmount > 0 || order.pointsUsed > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Subtotal:',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'S/ ${subtotalItems.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],

              // Descuento Adicional
              if (order.discountAmount > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Descuento:',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      '- S/ ${order.discountAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],

              // Mostrar solo si se usaron monedas/puntos
              if (order.pointsUsed > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Monedas usadas:',
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

    // 3. Imprimir / Compartir el PDF generado
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Pedido_${order.id.substring(0, 8)}.pdf',
    );
  }
}
