import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/receipt/receipt_dashed_divider.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/receipt/receipt_tax_helper.dart';

/// Previsualización interactiva fiel de Comprobante en formato Ticket Térmico 80mm.
class ReceiptTicketPreview extends StatelessWidget {
  final OrderEntity order;
  final List<OrderItemEntity> items;
  final String businessName;
  final String taxId;
  final String address;
  final String phone;
  final String shortId;
  final DateTime orderTime;
  final bool isCreditOrder;

  const ReceiptTicketPreview({
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
            Center(
              child: Text(
                businessName.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            if (taxId.isNotEmpty) ...[
              const SizedBox(height: 2),
              Center(
                child: Text(
                  'RUC: $taxId',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 2),
              Center(
                child: Text(
                  address,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Center(
                child: Text(
                  'Telf: $phone',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            const ReceiptDashedDivider(),
            const SizedBox(height: 8),

            // Metadatos del Comprobante
            Center(
              child: Text(
                order.documentType == 'FACTURA'
                    ? 'FACTURA ELECTRÓNICA'
                    : (order.documentType == 'BOLETA'
                        ? 'BOLETA DE VENTA ELECTRÓNICA'
                        : 'NOTA DE VENTA'),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Center(
              child: Text(
                order.displayReceiptNumber,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 6),

            _ticketRow(
              'FECHA:',
              DateFormat('dd/MM/yyyy HH:mm', 'es').format(orderTime),
            ),
            _ticketRow('CLIENTE:', order.displayCustomerName),
            if (order.customerDocumentNumber != null &&
                order.customerDocumentNumber!.isNotEmpty)
              _ticketRow(
                '${order.customerDocumentType ?? "DOC"}:',
                order.customerDocumentNumber!,
              ),
            if (order.customerAddress != null &&
                order.customerAddress!.isNotEmpty)
              _ticketRow('DIRECCIÓN:', order.customerAddress!),
            _ticketRow('PAGO:', order.paymentMethod),
            if (order.paymentReference != null &&
                order.paymentReference!.isNotEmpty)
              _ticketRow('REF. OPERACIÓN:', order.paymentReference!),
            if (isCreditOrder)
              _ticketRow(
                'CONDICIÓN:',
                order.paymentStatus.toUpperCase() == 'PARTIAL'
                    ? 'CRÉDITO (PAGO PARCIAL)'
                    : 'AL CRÉDITO (PENDIENTE)',
              ),

            const SizedBox(height: 8),
            const ReceiptDashedDivider(),
            const SizedBox(height: 8),

            // Tabla de Ítems
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CANT x DESCRIPCIÓN',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
                Text(
                  'IMPORTE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            for (final item in items) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity} x ${_itemDisplayName(item)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ReceiptTaxHelper.formatCurrency(item.subtotal),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            const ReceiptDashedDivider(),
            const SizedBox(height: 8),

            // Totales
            _ticketRow(
              'OP. GRAVADA:',
              ReceiptTaxHelper.formatCurrency(tax.opGravada),
            ),
            _ticketRow(
              'I.G.V. (18%):',
              ReceiptTaxHelper.formatCurrency(tax.igvAmount),
            ),
            if (tax.discountAmount > 0)
              _ticketRow(
                'DESCUENTO:',
                '- ${ReceiptTaxHelper.formatCurrency(tax.discountAmount)}',
              ),
            if (tax.pointsUsed > 0)
              _ticketRow('PUNTOS USADOS:', '- ${tax.pointsUsed} pts'),

            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL A PAGAR:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  ReceiptTaxHelper.formatCurrency(tax.totalAmount),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const ReceiptDashedDivider(),
            const SizedBox(height: 12),

            // Código QR SUNAT
            Center(
              child: SizedBox(
                height: 85,
                width: 85,
                child: BarcodeWidget(
                  barcode: Barcode.qrCode(),
                  data: OrderPdfGenerator.buildQrData(order, taxId: taxId),
                  drawText: false,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '#$shortId',
                style: const TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '¡Gracias por su compra!',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _itemDisplayName(OrderItemEntity item) {
    String displayName = item.productName ?? 'Producto';
    final vLabel = item.variantLabel.trim();
    if (item.hasVariantAttributes && vLabel.isNotEmpty) {
      displayName += ' ($vLabel)';
    }
    return displayName;
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
