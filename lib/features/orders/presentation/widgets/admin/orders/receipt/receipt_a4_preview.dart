import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/receipt/receipt_tax_helper.dart';

/// Previsualización interactiva de Comprobante en formato A4 / Factura Institucional.
class ReceiptA4Preview extends StatelessWidget {
  final OrderEntity order;
  final List<OrderItemEntity> items;
  final String businessName;
  final String taxId;
  final String address;
  final String phone;
  final String shortId;
  final DateTime orderTime;
  final bool isCreditOrder;

  const ReceiptA4Preview({
    super.key,
    required this.order,
    required this.items,
    required this.businessName,
    required this.taxId,
    required this.address,
    required this.phone,
    required this.shortId,
    required this.orderTime,
    required this.isCreditOrder,
  });

  @override
  Widget build(BuildContext context) {
    final tax = ReceiptTaxHelper.fromOrder(order);

    return RepaintBoundary(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera institucional
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (taxId.isNotEmpty)
                        Text(
                          'RUC: $taxId',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      if (address.isNotEmpty)
                        Text(
                          address,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      if (phone.isNotEmpty)
                        Text(
                          'Telf: $phone',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF0F172A),
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      if (taxId.isNotEmpty)
                        Text(
                          'R.U.C. $taxId',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                        order.documentType == 'FACTURA'
                            ? 'FACTURA ELECTRÓNICA'
                            : (order.documentType == 'BOLETA'
                                ? 'BOLETA ELECTRÓNICA'
                                : 'NOTA DE VENTA'),
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.displayReceiptNumber,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bloque del cliente
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente: ${order.displayCustomerName}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (order.customerDocumentNumber != null &&
                      order.customerDocumentNumber!.isNotEmpty)
                    Text(
                      '${order.customerDocumentType ?? "Documento"}: ${order.customerDocumentNumber}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  if (order.customerAddress != null &&
                      order.customerAddress!.isNotEmpty)
                    Text(
                      'Dirección: ${order.customerAddress}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm', 'es').format(orderTime)}  |  Pago: ${order.paymentMethod}${isCreditOrder ? " (Al Crédito)" : ""}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Tabla A4
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            'CANT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'DESCRIPCIÓN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final it in items)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4.5,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${it.quantity}',
                              style: const TextStyle(fontSize: 8.5),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              it.productName ?? 'Producto',
                              style: const TextStyle(fontSize: 8.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            ReceiptTaxHelper.formatCurrency(it.subtotal),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Totales y Código QR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 68,
                      width: 68,
                      child: BarcodeWidget(
                        barcode: Barcode.qrCode(),
                        data: OrderPdfGenerator.buildQrData(
                          order,
                          taxId: taxId,
                        ),
                        drawText: false,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#$shortId',
                      style: const TextStyle(
                        fontSize: 8,
                        fontFamily: 'monospace',
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 190,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'OP. GRAVADA:',
                            style: TextStyle(fontSize: 8.5),
                          ),
                          Text(
                            ReceiptTaxHelper.formatCurrency(tax.opGravada),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'I.G.V. (18%):',
                            style: TextStyle(fontSize: 8.5),
                          ),
                          Text(
                            ReceiptTaxHelper.formatCurrency(tax.igvAmount),
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 6, color: Color(0xFFE2E8F0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ReceiptTaxHelper.formatCurrency(tax.totalAmount),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
