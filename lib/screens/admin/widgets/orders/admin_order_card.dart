import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class AdminOrderCard extends StatelessWidget {
  final OrderModel order;
  final bool isProcessing;
  final bool isGeneratingPDF;
  final VoidCallback onTap;
  final Function(OrderModel, String) onUpdateStatus;
  final VoidCallback onPrint;

  const AdminOrderCard({
    super.key,
    required this.order,
    required this.isProcessing,
    this.isGeneratingPDF = false,
    required this.onTap,
    required this.onUpdateStatus,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final date = (order.createdAt ?? DateTime.now()).toLocal();
    final dateString = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final customerName = order.displayCustomerName;
    final shortId = order.id.substring(0, 8).toUpperCase();

    final isCredit = order.paymentMethod == 'CRÉDITO';

    // Calcular estado de pago dinámico
    String paymentStatus = order.paymentStatus;
    double amountPaid = order.amountPaid;
    if (status == 'COMPLETED' && !isCredit) {
      paymentStatus = 'PAID';
      amountPaid = order.totalAmount;
    }

    final totalAmount = order.totalAmount;
    final pendingAmount = totalAmount - amountPaid;
    final warehouseName = order.warehouseName;

    // Chip de puntos pendientes (crédito completado con puntos a ganar)
    final showPendingPointsChip =
        status == 'COMPLETED' &&
        isCredit &&
        paymentStatus != 'PAID' &&
        order.pointsEarned > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isProcessing ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Indicador de procesamiento ────────────────────────────
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(
                      color: AppColors.teal,
                      minHeight: 2,
                    ),
                  ),

                // ── Fila 1: Info Cliente e ID ─────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ID del pedido
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.tag_rounded,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shortId,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade700,
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Cliente
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Fecha
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateString,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Método de pago
                          Row(
                            children: [
                              Icon(
                                isCredit
                                    ? Icons.credit_card_rounded
                                    : Icons.payments_outlined,
                                size: 14,
                                color:
                                    isCredit
                                        ? Colors.deepOrange.shade400
                                        : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                order.paymentMethod,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isCredit
                                          ? Colors.deepOrange.shade600
                                          : Colors.grey.shade600,
                                  fontWeight:
                                      isCredit
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          if (warehouseName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.warehouse_outlined,
                                  size: 14,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  warehouseName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Chip: puntos pendientes de otorgar
                          if (showPendingPointsChip) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '🪙',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${order.pointsEarned} monedas pendientes de otorgar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Monto y Tags de Estado
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _StatusTag(status: status),
                        const SizedBox(height: 6),
                        _PaymentStatusTag(paymentStatus: paymentStatus),
                      ],
                    ),
                  ],
                ),

                // ── Progreso de pagos (Si es parcial o crédito) ───────────
                if (status == 'COMPLETED' && isCredit) ...[
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pagado: S/ ${amountPaid.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Resta: S/ ${pendingAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  pendingAmount > 0
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              totalAmount > 0 ? (amountPaid / totalAmount) : 0,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pendingAmount <= 0
                                ? Colors.green
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Línea Separadora ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.grey.shade200, height: 1),
                ),

                // ── Botones de Acción Rápida ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Imprimir Ticket (con animación si está generando)
                    TextButton.icon(
                      onPressed:
                          isProcessing || isGeneratingPDF ? null : onPrint,
                      icon:
                          isGeneratingPDF
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                Icons.print_rounded,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                      label: Text(
                        isGeneratingPDF ? 'Generando...' : 'Ticket',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    if (status == 'PENDING') ...[
                      // Botón Cancelar Borrador
                      TextButton.icon(
                        onPressed:
                            isProcessing
                                ? null
                                : () => onUpdateStatus(order, 'CANCELLED'),
                        icon: Icon(
                          Icons.cancel_outlined,
                          size: 18,
                          color: Colors.red.shade600,
                        ),
                        label: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botón Completar
                      ElevatedButton.icon(
                        onPressed:
                            isProcessing
                                ? null
                                : () => onUpdateStatus(order, 'COMPLETED'),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Cobrar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers: Etiquetas de estado ──────────────────────────────────────────

class _StatusTag extends StatelessWidget {
  final String status;
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'COMPLETED':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'COMPLETADO';
        icon = Icons.check_circle_rounded;
        break;
      case 'PENDING':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        label = 'BORRADOR';
        icon = Icons.edit_note_rounded;
        break;
      case 'CANCELLED':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        label = 'CANCELADO';
        icon = Icons.cancel_rounded;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusTag extends StatelessWidget {
  final String paymentStatus;
  const _PaymentStatusTag({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (paymentStatus) {
      case 'PAID':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'PAGADO';
        icon = Icons.done_all_rounded;
        break;
      case 'PARTIAL':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        label = 'PARCIAL';
        icon = Icons.donut_large_rounded;
        break;
      case 'PENDING':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        label = 'POR COBRAR';
        icon = Icons.hourglass_empty_rounded;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = paymentStatus;
        icon = Icons.payments_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
