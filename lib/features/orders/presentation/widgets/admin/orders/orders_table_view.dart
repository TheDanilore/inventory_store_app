import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

class OrdersTableView extends StatefulWidget {
  final List<OrderEntity> orders;
  final OrderEntity? selectedOrder;
  final Function(OrderEntity) onSelectOrder;
  final Function(OrderEntity) onPrintTicket;
  final Function(OrderEntity, String) onUpdateStatus;
  final bool isProcessing;

  const OrdersTableView({
    super.key,
    required this.orders,
    required this.selectedOrder,
    required this.onSelectOrder,
    required this.onPrintTicket,
    required this.onUpdateStatus,
    this.isProcessing = false,
  });

  @override
  State<OrdersTableView> createState() => _OrdersTableViewState();
}

class _OrdersTableViewState extends State<OrdersTableView> {
  String? _hoveredId;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = AppColors.successLight;
        text = AppColors.successDark;
        label = 'Completado';
        icon = Icons.check_circle_rounded;
        break;
      case 'DRAFT':
        bg = AppColors.warningLight;
        text = AppColors.warningDark;
        label = 'Borrador';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'CANCELLED':
        bg = AppColors.dangerLight;
        text = AppColors.danger;
        label = 'Cancelado';
        icon = Icons.cancel_rounded;
        break;
      case 'RETURNED':
        bg = Colors.purple.shade50;
        text = Colors.purple.shade700;
        label = 'Devuelto';
        icon = Icons.assignment_return_rounded;
        break;
      default:
        bg = Colors.grey.shade100;
        text = AppColors.textSecondary;
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus, String method, double pending) {
    final isPaid = paymentStatus.toUpperCase() == 'PAID';
    final bg = isPaid ? AppColors.successLight : AppColors.warningLight;
    final text = isPaid ? AppColors.successDark : AppColors.warningDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isPaid ? 'Pagado' : (pending > 0 ? 'Por Cobrar' : 'Pendiente'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ),
        if (method.isNotEmpty && method != 'POR ACORDAR') ...[
          const SizedBox(height: 2),
          Text(
            method,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 880.0;
        final tableWidth = constraints.maxWidth < minTableWidth
            ? minTableWidth
            : constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
          // --- Encabezado Fijo de Tabla ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    'ID PEDIDO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    'FECHA / HORA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'CLIENTE / DESTINO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'ESTADO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'PAGO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'ACCIONES',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Lista de Filas ---
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.orders.length,
            separatorBuilder:
                (_, _) =>
                    const Divider(height: 1, thickness: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final order = widget.orders[index];
              final isSelected = widget.selectedOrder?.id == order.id;

              final shortId =
                  order.id.length >= 8
                      ? order.id.substring(0, 8).toUpperCase()
                      : order.id.toUpperCase();
              final date = (order.createdAt ?? DateTime.now()).toLocal();
              final dateFormatted = DateFormat('dd MMM, hh:mm a', 'es').format(date);
              final pending = order.totalAmount - order.amountPaid;

              final isHovered = _hoveredId == order.id;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoveredId = order.id),
                onExit: (_) => setState(() => _hoveredId = null),
                child: InkWell(
                  onTap: () => widget.onSelectOrder(order),
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.tealLight.withValues(alpha: 0.45)
                          : (isHovered ? const Color(0xFFF8FAFC) : Colors.transparent),
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? AppColors.teal : Colors.transparent,
                          width: 3.5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        // ID Pedido
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => _copyToClipboard(context, shortId, 'ID'),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    '#$shortId',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Fecha / Hora
                        SizedBox(
                          width: 130,
                          child: Text(
                            dateFormatted,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Cliente / Sucursal
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                order.displayCustomerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                (order.warehouseName != null && order.warehouseName!.isNotEmpty)
                                    ? order.warehouseName!
                                    : 'Tienda Principal',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Estado
                        SizedBox(
                          width: 120,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildStatusBadge(order.status),
                          ),
                        ),

                        // Pago
                        SizedBox(
                          width: 110,
                          child: _buildPaymentBadge(
                            order.paymentStatus,
                            order.paymentMethod,
                            pending,
                          ),
                        ),

                        // Total
                        SizedBox(
                          width: 110,
                          child: Text(
                            'S/ ${order.totalAmount.toStringAsFixed(2)}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),

                        // Acciones Rápidas
                        SizedBox(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                tooltip: 'Imprimir Ticket [P]',
                                onPressed: () => widget.onPrintTicket(order),
                              ),
                              if (order.status == 'DRAFT')
                                IconButton(
                                  icon: const Icon(
                                    Icons.payments_rounded,
                                    size: 18,
                                    color: AppColors.teal,
                                  ),
                                  tooltip: 'Completar / Cobrar',
                                  onPressed:
                                      () => widget.onUpdateStatus(
                                        order,
                                        'COMPLETED',
                                      ),
                                )
                              else
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: AppColors.textMuted,
                                  ),
                                  tooltip: 'Ver detalle',
                                  onPressed: () => widget.onSelectOrder(order),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  ),
);
      },
    );
  }
}
