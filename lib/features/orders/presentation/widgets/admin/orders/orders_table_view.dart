import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

class OrdersTableView extends StatelessWidget {
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.2),
            boxShadow: AppColors.cardShadow(opacity: 0.04),
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
                  // --- Encabezado Fijo de Tabla (Slate Tonal Header) ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9), // Slate 100
                      border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'ID PEDIDO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: Text(
                            'FECHA / HORA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'CLIENTE / DESTINO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'ESTADO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            'PAGO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                              letterSpacing: 0.5,
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
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                              letterSpacing: 0.5,
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
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                              letterSpacing: 0.5,
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
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final isSelected = selectedOrder?.id == order.id;

                      return _OrderTableRow(
                        key: ValueKey(order.id),
                        order: order,
                        isSelected: isSelected,
                        onSelect: () => onSelectOrder(order),
                        onPrintTicket: () => onPrintTicket(order),
                        onUpdateStatus: (s) => onUpdateStatus(order, s),
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

// ─────────────────────────────────────────────────────────────────────────────
// FILA AISLADA DE PEDIDO CON HOVER SUAVE
// ─────────────────────────────────────────────────────────────────────────────

class _OrderTableRow extends StatefulWidget {
  final OrderEntity order;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onPrintTicket;
  final ValueChanged<String> onUpdateStatus;

  const _OrderTableRow({
    super.key,
    required this.order,
    required this.isSelected,
    required this.onSelect,
    required this.onPrintTicket,
    required this.onUpdateStatus,
  });

  @override
  State<_OrderTableRow> createState() => _OrderTableRowState();
}

class _OrderTableRowState extends State<_OrderTableRow> {
  bool _isHovered = false;

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
    Color border;
    Color text;
    String label;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFA7F3D0);
        text = const Color(0xFF047857);
        label = 'Completado';
        icon = Icons.check_circle_rounded;
        break;
      case 'DRAFT':
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFB45309);
        label = 'Borrador';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFFF1F2);
        border = const Color(0xFFFECDD3);
        text = const Color(0xFFBE123C);
        label = 'Cancelado';
        icon = Icons.cancel_rounded;
        break;
      case 'RETURNED':
        bg = const Color(0xFFF5F3FF);
        border = const Color(0xFFDDD6FE);
        text = const Color(0xFF6D28D9);
        label = 'Devuelto';
        icon = Icons.assignment_return_rounded;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF475569);
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: text),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus, String method, double pending) {
    final isPaid = paymentStatus.toUpperCase() == 'PAID';
    final Color bg = isPaid
        ? const Color(0xFFECFDF5)
        : (pending > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9));
    final Color border = isPaid
        ? const Color(0xFFA7F3D0)
        : (pending > 0 ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1));
    final Color text = isPaid
        ? const Color(0xFF047857)
        : (pending > 0 ? const Color(0xFFB45309) : const Color(0xFF475569));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: border, width: 1),
          ),
          child: Text(
            isPaid ? 'Pagado' : (pending > 0 ? 'Por Cobrar' : 'Pendiente'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ),
        if (method.isNotEmpty && method != 'POR ACORDAR') ...[
          const SizedBox(height: 2),
          Text(
            method,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
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
    final order = widget.order;
    final isSelected = widget.isSelected;

    final shortId = order.id.length >= 8
        ? order.id.substring(0, 8).toUpperCase()
        : order.id.toUpperCase();
    final date = (order.createdAt ?? DateTime.now()).toLocal();
    final dateFormatted = DateFormat('dd MMM, hh:mm a', 'es').format(date);
    final pending = order.totalAmount - order.amountPaid;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onSelect,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF0FDFA)
                : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
            border: Border(
              left: BorderSide(
                color: isSelected ? const Color(0xFF0D9488) : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
          child: Row(
            children: [
              // 1. ID Pedido
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _copyToClipboard(context, shortId, 'ID'),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          '#$shortId',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Fecha / Hora
              SizedBox(
                width: 130,
                child: Text(
                  dateFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // 3. Cliente / Sucursal
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      order.displayCustomerName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (order.warehouseName != null && order.warehouseName!.isNotEmpty)
                          ? order.warehouseName!
                          : 'Tienda Principal',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 4. Estado
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(order.status),
                ),
              ),

              // 5. Pago
              SizedBox(
                width: 110,
                child: _buildPaymentBadge(
                  order.paymentStatus,
                  order.paymentMethod,
                  pending,
                ),
              ),

              // 6. Total
              SizedBox(
                width: 110,
                child: RichText(
                  textAlign: TextAlign.end,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'S/ ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                      TextSpan(
                        text: order.totalAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Inter',
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Acciones Rápidas
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.receipt_long_rounded,
                        size: 19,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Imprimir Ticket [P]',
                      hoverColor: const Color(0xFFF1F5F9),
                      onPressed: widget.onPrintTicket,
                    ),
                    if (order.status == 'DRAFT')
                      IconButton(
                        icon: const Icon(
                          Icons.payments_rounded,
                          size: 19,
                          color: AppColors.teal,
                        ),
                        tooltip: 'Completar / Cobrar',
                        onPressed: () => widget.onUpdateStatus('COMPLETED'),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          size: 21,
                          color: _isHovered ? AppColors.teal : const Color(0xFF94A3B8),
                        ),
                        tooltip: 'Ver detalle',
                        onPressed: widget.onSelect,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
