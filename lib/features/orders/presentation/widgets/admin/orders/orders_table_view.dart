import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

class OrdersTableView extends StatefulWidget {
  final List<OrderEntity> orders;
  final OrderEntity? selectedOrder;
  final Function(OrderEntity) onSelectOrder;
  final Function(OrderEntity) onPrintTicket;
  final Function(OrderEntity, String) onUpdateStatus;
  final bool isProcessing;
  final AdminTablePaginationConfig? paginationConfig;

  const OrdersTableView({
    super.key,
    required this.orders,
    required this.selectedOrder,
    required this.onSelectOrder,
    required this.onPrintTicket,
    required this.onUpdateStatus,
    this.isProcessing = false,
    this.paginationConfig,
  });

  @override
  State<OrdersTableView> createState() => _OrdersTableViewState();
}

class _OrdersTableViewState extends State<OrdersTableView> {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId;
  bool _isSortAscending = true;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  List<OrderEntity> _getSortedOrders() {
    if (_sortColumnId == null) return widget.orders;
    final list = List<OrderEntity>.from(widget.orders);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'id':
          cmp = a.id.compareTo(b.id);
          break;
        case 'date':
          final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          cmp = dateA.compareTo(dateB);
          break;
        case 'customer':
          cmp = a.displayCustomerName.toLowerCase().compareTo(
            b.displayCustomerName.toLowerCase(),
          );
          break;
        case 'status':
          cmp = a.status.toLowerCase().compareTo(b.status.toLowerCase());
          break;
        case 'total':
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
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

  Widget _buildPaymentBadge(
    String paymentStatus,
    String method,
    double pending, {
    String? orderStatus,
    String? paymentReference,
  }) {
    final isCancelled = orderStatus?.toUpperCase() == 'CANCELLED';
    final isReturned = orderStatus?.toUpperCase() == 'RETURNED';
    final isPaid = paymentStatus.toUpperCase() == 'PAID';

    final Color bg;
    final Color border;
    final Color text;
    final String label;

    if (isCancelled) {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      text = const Color(0xFFDC2626);
      label = 'Anulado';
    } else if (isReturned) {
      bg = const Color(0xFFF5F3FF);
      border = const Color(0xFFDDD6FE);
      text = const Color(0xFF6D28D9);
      label = 'Devuelto';
    } else if (isPaid) {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      text = const Color(0xFF047857);
      label = 'Pagado';
    } else {
      bg = pending > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF1F5F9);
      border = pending > 0 ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1);
      text = pending > 0 ? const Color(0xFFB45309) : const Color(0xFF475569);
      label = pending > 0 ? 'Por Cobrar' : 'Pendiente';
    }

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
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ),
        if (method.isNotEmpty && method != 'POR ACORDAR') ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (paymentReference != null &&
                  paymentReference.trim().isNotEmpty) ...[
                const Text(
                  ' · ',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                Flexible(
                  child: Text(
                    'Op: ${paymentReference.trim()}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedOrders = _getSortedOrders();

    return AdminProTable<OrderEntity>(
      items: sortedOrders,
      itemId: (o) => o.id,
      selectedIds: _selectedIds,
      onSelectionChanged: (newSet) {
        setState(() {
          _selectedIds.clear();
          _selectedIds.addAll(newSet);
        });
      },
      sortColumnId: _sortColumnId,
      isSortAscending: _isSortAscending,
      onSort: (colId, isAsc) {
        setState(() {
          _sortColumnId = colId;
          _isSortAscending = isAsc;
        });
      },
      paginationConfig: widget.paginationConfig,
      onRowTap: widget.onSelectOrder,
      minTableWidth: 920.0,
      margin: EdgeInsets.zero,
      bulkActions: [
        AdminBulkAction<OrderEntity>(
          label: 'Imprimir Tickets',
          icon: Icons.receipt_long_rounded,
          customColor: AppColors.teal,
          onPressed: (selectedList) {
            for (final order in selectedList) {
              widget.onPrintTicket(order);
            }
            AppSnackbar.show(
              context,
              message:
                  'Imprimiendo ${selectedList.length} tickets seleccionados...',
              type: SnackbarType.success,
            );
          },
        ),
        AdminBulkAction<OrderEntity>(
          label: 'Copiar IDs',
          icon: Icons.copy_rounded,
          onPressed: (selectedList) {
            final ids = selectedList
                .map(
                  (o) =>
                      o.id.length >= 8
                          ? '#${o.id.substring(0, 8).toUpperCase()}'
                          : '#${o.id.toUpperCase()}',
                )
                .join(', ');
            _copyToClipboard(context, ids, '${selectedList.length} IDs');
          },
        ),
        AdminBulkAction<OrderEntity>(
          label: 'Completar Borradores',
          icon: Icons.check_circle_outline_rounded,
          onPressed: (selectedList) {
            final drafts =
                selectedList
                    .where(
                      (o) =>
                          o.status.toUpperCase() == 'DRAFT' ||
                          o.status.toUpperCase() == 'PENDING',
                    )
                    .toList();
            if (drafts.isEmpty) {
              AppSnackbar.show(
                context,
                message:
                    'No hay pedidos en estado Borrador o Pendiente seleccionados',
                type: SnackbarType.info,
              );
              return;
            }
            for (final draft in drafts) {
              widget.onUpdateStatus(draft, 'COMPLETED');
            }
            AppSnackbar.show(
              context,
              message: 'Completando ${drafts.length} pedidos seleccionados...',
              type: SnackbarType.success,
            );
          },
        ),
      ],
      columns: [
        // 1. ID Pedido
        AdminTableColumn<OrderEntity>(
          id: 'id',
          label: 'ID PEDIDO',
          fixedWidth: 135,
          isSortable: true,
          tooltip: 'Identificador del pedido y comprobante',
          cellBuilder: (context, order) {
            final shortId =
                order.id.length >= 8
                    ? order.id.substring(0, 8).toUpperCase()
                    : order.id.toUpperCase();
            final hasDoc =
                order.documentNumber != null &&
                order.documentNumber!.trim().isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
                if (hasDoc) ...[
                  const SizedBox(height: 3),
                  InkWell(
                    onTap:
                        () => _copyToClipboard(
                          context,
                          order.documentNumber!.trim(),
                          'Comprobante',
                        ),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (order.documentType.toUpperCase() == 'FACTURA')
                                ? const Color(0xFFF3E8FF)
                                : ((order.documentType.toUpperCase() ==
                                        'BOLETA')
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              (order.documentType.toUpperCase() == 'FACTURA')
                                  ? const Color(0xFFD8B4FE)
                                  : ((order.documentType.toUpperCase() ==
                                          'BOLETA')
                                      ? const Color(0xFFBFDBFE)
                                      : const Color(0xFFA7F3D0)),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        order.documentNumber!.trim(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          color:
                              (order.documentType.toUpperCase() == 'FACTURA')
                                  ? const Color(0xFF7E22CE)
                                  : ((order.documentType.toUpperCase() ==
                                          'BOLETA')
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF047857)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),

        // 2. Fecha / Hora
        AdminTableColumn<OrderEntity>(
          id: 'date',
          label: 'FECHA / HORA',
          fixedWidth: 135,
          isSortable: true,
          tooltip: 'Fecha y hora de registro',
          cellBuilder: (context, order) {
            final date = (order.createdAt ?? DateTime.now()).toLocal();
            final dateFormatted = DateFormat(
              'dd MMM, hh:mm a',
              'es',
            ).format(date);
            return Text(
              dateFormatted,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),

        // 3. Cliente / Sucursal
        AdminTableColumn<OrderEntity>(
          id: 'customer',
          label: 'CLIENTE / DESTINO',
          flex: 2,
          isSortable: true,
          tooltip: 'Cliente asociado o venta rápida',
          cellBuilder: (context, order) {
            return Column(
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
                  (order.warehouseName != null &&
                          order.warehouseName!.isNotEmpty)
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
            );
          },
        ),

        // 4. Estado
        AdminTableColumn<OrderEntity>(
          id: 'status',
          label: 'ESTADO',
          flex: 2,
          isSortable: true,
          tooltip: 'Estado actual del pedido',
          cellBuilder: (context, order) {
            return Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(order.status),
            );
          },
        ),

        // 5. Pago
        AdminTableColumn<OrderEntity>(
          id: 'payment',
          label: 'PAGO',
          flex: 2,
          isSortable: false,
          tooltip: 'Estado de pago y método',
          cellBuilder: (context, order) {
            final pending = order.totalAmount - order.amountPaid;
            return _buildPaymentBadge(
              order.paymentStatus,
              order.paymentMethod,
              pending,
              orderStatus: order.status,
              paymentReference: order.paymentReference,
            );
          },
        ),

        // 6. Total
        AdminTableColumn<OrderEntity>(
          id: 'total',
          label: 'TOTAL',
          fixedWidth: 115,
          alignment: Alignment.centerRight,
          isSortable: true,
          tooltip: 'Monto total del pedido',
          cellBuilder: (context, order) {
            return RichText(
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
            );
          },
        ),

        // 7. Acciones Rápidas
        AdminTableColumn<OrderEntity>(
          id: 'actions',
          label: 'ACCIONES',
          fixedWidth: 115,
          alignment: Alignment.centerRight,
          isSortable: false,
          cellBuilder: (context, order) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    size: 19,
                    color: Color(0xFF64748B),
                  ),
                  tooltip: 'Imprimir Ticket',
                  hoverColor: const Color(0xFFF1F5F9),
                  onPressed: () => widget.onPrintTicket(order),
                ),
                if (order.status.toUpperCase() == 'DRAFT' ||
                    order.status.toUpperCase() == 'PENDING')
                  IconButton(
                    icon: const Icon(
                      Icons.payments_rounded,
                      size: 19,
                      color: AppColors.teal,
                    ),
                    tooltip: 'Completar / Cobrar',
                    onPressed: () => widget.onUpdateStatus(order, 'COMPLETED'),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      size: 21,
                      color: Color(0xFF94A3B8),
                    ),
                    tooltip: 'Ver detalle',
                    onPressed: () => widget.onSelectOrder(order),
                  ),
              ],
            );
          },
        ),
      ],
      mobileCardBuilder: (context, order, isSelected, onSelect) {
        final shortId =
            order.id.length >= 8
                ? order.id.substring(0, 8).toUpperCase()
                : order.id.toUpperCase();
        final date = (order.createdAt ?? DateTime.now()).toLocal();
        final dateFormatted = DateFormat('dd MMM, hh:mm a', 'es').format(date);
        final pending = order.totalAmount - order.amountPaid;

        return InkWell(
          onTap: () => widget.onSelectOrder(order),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0FDFA) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.teal : AppColors.border,
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.03),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: ID, Date, and Select checkbox
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
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
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateFormatted,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.receipt_long_rounded,
                            size: 19,
                            color: Color(0xFF64748B),
                          ),
                          tooltip: 'Imprimir',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          onPressed: () => widget.onPrintTicket(order),
                        ),
                        Checkbox(
                          value: isSelected,
                          activeColor: AppColors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) => onSelect(val ?? false),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Customer info
                Text(
                  order.displayCustomerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  (order.warehouseName != null &&
                          order.warehouseName!.isNotEmpty)
                      ? order.warehouseName!
                      : 'Tienda Principal',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),

                // Bottom row: Badges and Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildStatusBadge(order.status),
                        const SizedBox(width: 6),
                        _buildPaymentBadge(
                          order.paymentStatus,
                          order.paymentMethod,
                          pending,
                          orderStatus: order.status,
                        ),
                      ],
                    ),
                    RichText(
                      textAlign: TextAlign.end,
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'S/ ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          TextSpan(
                            text: order.totalAmount.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
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
      },
    );
  }
}
