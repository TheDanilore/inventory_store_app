import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/models/order_item_model.dart';

class OrderPdfGenerator {
  static Future<void> generateTicket(
    OrderModel order, {
    List<OrderItemModel>? items,
  }) async {
    // 1. Obtener los items si no se pasaron por parámetro (caso de la OrderCard)
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

    // 2. Configurar el documento PDF (Formato Ticket de 80mm aprox)
    final pdf = pw.Document();

    final dateString = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(order.createdAt ?? DateTime.now());

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
              pw.Text('Estado: ${order.status}'),
              pw.Text('Método Pago: ${order.paymentMethod}'),

              pw.Text('Estado de Pago: ${order.paymentStatus}'),

              pw.Text(
                'Monto Pagado: S/ ${order.amountPaid.toStringAsFixed(2)}',
              ),

              order.dueDate != null
                  ? pw.Text(
                    'Fecha de Vencimiento: ${DateFormat('dd/MM/yyyy').format(order.dueDate!)}',
                  )
                  : pw.Container(),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // ITEMS
              pw.Text(
                'CANT  DESCRIPCION      TOTAL',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
                        width: 30,
                        child: pw.Text('${item.quantity}x'),
                      ),
                      pw.Expanded(child: pw.Text(itemName)),
                      pw.SizedBox(
                        width: 50,
                        child: pw.Text(
                          'S/ $subtotal',
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // TOTALES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Monedas usadas:'),
                  pw.Text('- ${order.pointsUsed} pts'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL FINAL:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.Text(
                    'S/ ${order.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
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
