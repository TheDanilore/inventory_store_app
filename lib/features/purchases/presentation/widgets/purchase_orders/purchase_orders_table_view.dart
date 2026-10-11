import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';

class PurchaseOrdersTableView extends StatefulWidget {
  final List<PurchaseOrderModel> orders;
  final PurchaseOrderModel? selectedOrder;
  final ValueChanged<PurchaseOrderModel> onSelectOrder;
  final VoidCallback? onRefresh;
  final AdminTablePaginationConfig? paginationConfig;

  const PurchaseOrdersTableView({
    super.key,
    required this.orders,
    required this.selectedOrder,
    required this.onSelectOrder,
    this.onRefresh,
    this.paginationConfig,
  });

  @override
  State<PurchaseOrdersTableView> createState() => _PurchaseOrdersTableViewState();
}

class _PurchaseOrdersTableViewState extends State<PurchaseOrdersTableView> {
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

  List<PurchaseOrderModel> _getSortedOrders() {
    if (_sortColumnId == null) return widget.orders;
    final list = List<PurchaseOrderModel>.from(widget.orders);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'id':
          cmp = a.id.compareTo(b.id);
          break;
        case 'date':
          cmp = a.createdAt.compareTo(b.createdAt);
          break;
        case 'supplier':
          cmp = a.supplierName.toLowerCase().compareTo(b.supplierName.toLowerCase());
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
      case 'RECEIVED':
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFFA7F3D0);
        text = const Color(0xFF047857);
        label = 'Recibido';
        icon = Icons.task_alt_rounded;
        break;
      case 'SENT':
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFBFDBFE);
        text = const Color(0xFF1D4ED8);
        label = 'Enviado';
        icon = Icons.local_shipping_rounded;
        break;
      case 'PARTIAL':
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFB45309);
        label = 'Parcial';
        icon = Icons.pie_chart_outline_rounded;
        break;
      case 'PENDING':
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFDE68A);
        text = const Color(0xFFD97706);
        label = 'Pendiente';
        icon = Icons.schedule_rounded;
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFFF1F2);
        border = const Color(0xFFFECDD3);
        text = const Color(0xFFBE123C);
        label = 'Cancelado';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = const Color(0xFF475569);
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(PurchaseOrderModel po) {
    final isCancelled = po.status == 'CANCELLED';
    if (isCancelled) {
      return Text(
        'Anulado',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted.withValues(alpha: 0.8),
        ),
      );
    }

    final isCredit = po.paymentMethod.toUpperCase().contains('CREDIT') ||
        po.paymentMethod.toUpperCase().contains('CRÉDIT');
    final debt = (po.totalAmount - po.amountPaid).clamp(0.0, double.infinity);
    final isPaid = po.paymentStatus.toUpperCase() == 'PAID' ||
        (!isCredit && po.status == 'RECEIVED') ||
        (po.amountPaid >= po.totalAmount && po.totalAmount > 0);

    Widget badgeWidget;

    if (isPaid) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF047857)),
            SizedBox(width: 4),
            Text(
              'Pagado',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF047857),
              ),
            ),
          ],
        ),
      );
    } else if (isCredit && debt > 0) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFFD97706),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Por Pagar: S/ ${debt.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD97706),
              ),
            ),
          ],
        ),
      );
    } else if (po.status == 'PENDING') {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        child: const Text(
          'Pendiente',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
      );
    } else {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1),
        ),
        child: Text(
          debt > 0 ? 'Por Pagar: S/ ${debt.toStringAsFixed(2)}' : 'Pendiente',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFFD97706),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        badgeWidget,
        if (po.paymentMethod.isNotEmpty && po.paymentMethod != 'POR ACORDAR') ...[
          const SizedBox(height: 2),
          Text(
            po.paymentMethod,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
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
    final sortedOrders = _getSortedOrders();

    return AdminProTable<PurchaseOrderModel>(
      items: sortedOrders,
      itemId: (po) => po.id,
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
        AdminBulkAction<PurchaseOrderModel>(
          label: 'Copiar IDs',
          icon: Icons.copy_rounded,
          onPressed: (selectedList) {
            final ids = selectedList
                .map((po) => po.id.length >= 8 ? '#${po.id.substring(0, 8).toUpperCase()}' : '#${po.id.toUpperCase()}')
                .join(', ');
            _copyToClipboard(context, ids, '${selectedList.length} IDs');
          },
        ),
        AdminBulkAction<PurchaseOrderModel>(
          label: 'Copiar Resumen de Compras',
          icon: Icons.summarize_rounded,
          customColor: AppColors.teal,
          onPressed: (selectedList) {
            final double total = selectedList.fold(0.0, (sum, po) => sum + po.totalAmount);
            final summary = selectedList
                .map((po) => '- #${po.id.substring(0, 8).toUpperCase()} | ${po.supplierName} | S/ ${po.totalAmount.toStringAsFixed(2)} [${po.status}]')
                .join('\n');
            final fullText = 'RESUMEN DE ÓRDENES DE COMPRA (${selectedList.length})\n$summary\nTotal acumulado: S/ ${total.toStringAsFixed(2)}';
            _copyToClipboard(context, fullText, 'Resumen de compras');
          },
        ),
      ],
      columns: [
        // 1. ID Orden
        AdminTableColumn<PurchaseOrderModel>(
          id: 'id',
          label: 'ID ORDEN',
          fixedWidth: 105,
          isSortable: true,
          tooltip: 'Identificador de la orden de compra',
          cellBuilder: (context, po) {
            final shortId = po.id.length >= 8
                ? po.id.substring(0, 8).toUpperCase()
                : po.id.toUpperCase();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _copyToClipboard(context, shortId, 'ID'),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            );
          },
        ),

        // 2. Fecha / Hora
        AdminTableColumn<PurchaseOrderModel>(
          id: 'date',
          label: 'FECHA / HORA',
          fixedWidth: 135,
          isSortable: true,
          tooltip: 'Fecha de emisión',
          cellBuilder: (context, po) {
            final date = po.createdAt.toLocal();
            final dateFormatted = DateFormat('dd MMM, hh:mm a', 'es').format(date);
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

        // 3. Proveedor / Documento
        AdminTableColumn<PurchaseOrderModel>(
          id: 'supplier',
          label: 'PROVEEDOR',
          flex: 2,
          isSortable: true,
          tooltip: 'Proveedor y comprobante asociado',
          cellBuilder: (context, po) {
            final hasDocument = po.documentType.isNotEmpty &&
                po.documentType.toUpperCase() != 'NINGUNO' &&
                po.documentType.toUpperCase() != 'SIN DOCUMENTO';
            final docSubtitle = hasDocument
                ? '${po.documentType} ${po.documentNumber ?? ""}'.trim()
                : (po.warehouseName ?? 'Almacén Principal');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  po.supplierName.isNotEmpty ? po.supplierName : 'Sin Proveedor',
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
                  docSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
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
        AdminTableColumn<PurchaseOrderModel>(
          id: 'status',
          label: 'ESTADO',
          flex: 2,
          isSortable: true,
          tooltip: 'Estado logístico de la orden',
          cellBuilder: (context, po) {
            return Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(po.status),
            );
          },
        ),

        // 5. Pago / Deuda
        AdminTableColumn<PurchaseOrderModel>(
          id: 'payment',
          label: 'PAGO / ESTADO',
          flex: 2,
          isSortable: false,
          tooltip: 'Estado financiero de la compra',
          cellBuilder: (context, po) {
            return _buildPaymentBadge(po);
          },
        ),

        // 6. Total
        AdminTableColumn<PurchaseOrderModel>(
          id: 'total',
          label: 'TOTAL',
          fixedWidth: 115,
          alignment: Alignment.centerRight,
          isSortable: true,
          tooltip: 'Monto total de la compra',
          cellBuilder: (context, po) {
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
                    text: po.totalAmount.toStringAsFixed(2),
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

        // 7. Acciones
        AdminTableColumn<PurchaseOrderModel>(
          id: 'actions',
          label: 'ACCIONES',
          fixedWidth: 110,
          alignment: Alignment.centerRight,
          isSortable: false,
          cellBuilder: (context, po) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    size: 19,
                    color: Color(0xFF64748B),
                  ),
                  tooltip: 'Ver detalle',
                  hoverColor: const Color(0xFFF1F5F9),
                  onPressed: () => widget.onSelectOrder(po),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Abrir orden',
                  onPressed: () => widget.onSelectOrder(po),
                ),
              ],
            );
          },
        ),
      ],
      mobileCardBuilder: (context, po, isSelected, onSelect) {
        final shortId = po.id.length >= 8
            ? po.id.substring(0, 8).toUpperCase()
            : po.id.toUpperCase();
        final date = po.createdAt.toLocal();
        final dateFormatted = DateFormat('dd MMM, hh:mm a', 'es').format(date);
        final hasDocument = po.documentType.isNotEmpty &&
            po.documentType.toUpperCase() != 'NINGUNO' &&
            po.documentType.toUpperCase() != 'SIN DOCUMENTO';
        final docSubtitle = hasDocument
            ? '${po.documentType} ${po.documentNumber ?? ""}'.trim()
            : (po.warehouseName ?? 'Almacén Principal');

        return InkWell(
          onTap: () => widget.onSelectOrder(po),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) => onSelect(val ?? false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  po.supplierName.isNotEmpty ? po.supplierName : 'Sin Proveedor',
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
                  docSubtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildStatusBadge(po.status),
                        const SizedBox(width: 6),
                        _buildPaymentBadge(po),
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
                            text: po.totalAmount.toStringAsFixed(2),
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
