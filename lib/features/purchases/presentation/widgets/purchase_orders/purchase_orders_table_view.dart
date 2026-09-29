import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';

class PurchaseOrdersTableView extends StatefulWidget {
  final List<PurchaseOrderModel> orders;
  final PurchaseOrderModel? selectedOrder;
  final ValueChanged<PurchaseOrderModel> onSelectOrder;
  final VoidCallback? onRefresh;

  const PurchaseOrdersTableView({
    super.key,
    required this.orders,
    required this.selectedOrder,
    required this.onSelectOrder,
    this.onRefresh,
  });

  @override
  State<PurchaseOrdersTableView> createState() => _PurchaseOrdersTableViewState();
}

class _PurchaseOrdersTableViewState extends State<PurchaseOrdersTableView> {
  String? _hoveredOrderId;

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
      case 'RECEIVED':
        bg = AppColors.successLight;
        text = AppColors.successDark;
        label = 'Recibido';
        icon = Icons.task_alt_rounded;
        break;
      case 'SENT':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'Enviado';
        icon = Icons.local_shipping_rounded;
        break;
      case 'PARTIAL':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Parcial';
        icon = Icons.pie_chart_outline_rounded;
        break;
      case 'PENDING':
        bg = AppColors.warningLight;
        text = AppColors.warningDark;
        label = 'Pendiente';
        icon = Icons.schedule_rounded;
        break;
      case 'CANCELLED':
        bg = AppColors.dangerLight;
        text = AppColors.danger;
        label = 'Cancelado';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = Colors.grey.shade100;
        text = AppColors.textSecondary;
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBadge(PurchaseOrderModel po) {
    final isCancelled = po.status == 'CANCELLED';
    final debt = isCancelled
        ? 0.0
        : (po.totalAmount - po.amountPaid).clamp(0.0, double.infinity);
    final isPaid = !isCancelled && (po.paymentStatus == 'PAID' || debt <= 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: isPaid ? AppColors.successLight : AppColors.warningLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isPaid
                ? 'Pagado'
                : 'Deuda: S/ ${debt.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isPaid ? AppColors.successDark : AppColors.warningDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (po.paymentMethod.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            po.paymentMethod,
            style: const TextStyle(
              fontSize: 9.5,
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
        const minTableWidth = 860.0;
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 85,
                          child: Text(
                            'ID ORDEN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 105,
                          child: Text(
                            'FECHA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'PROVEEDOR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 105,
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
                          width: 125,
                          child: Text(
                            'PAGO / DEUDA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 95,
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
                        SizedBox(width: 40),
                      ],
                    ),
                  ),

                  // --- Lista de Filas ---
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.orders.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final po = widget.orders[index];
                      final isHovered = _hoveredOrderId == po.id;
                      final isSelected = widget.selectedOrder?.id == po.id;

                      final shortId = po.id.length >= 8
                          ? po.id.substring(0, 8).toUpperCase()
                          : po.id.toUpperCase();
                      final date = po.createdAt.toLocal();
                      final dateFormatted = DateFormat('dd MMM, hh:mm a', 'es').format(date);

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => setState(() => _hoveredOrderId = po.id),
                        onExit: (_) => setState(() => _hoveredOrderId = null),
                        child: InkWell(
                          onTap: () => widget.onSelectOrder(po),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.tealLight.withValues(alpha: 0.45)
                                  : (isHovered
                                      ? const Color(0xFFF8FAFC)
                                      : Colors.transparent),
                              border: Border(
                                left: BorderSide(
                                  color: isSelected ? AppColors.teal : Colors.transparent,
                                  width: 3.5,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // ID Orden
                                SizedBox(
                                  width: 85,
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () => _copyToClipboard(context, shortId, 'ID'),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
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
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Fecha
                                SizedBox(
                                  width: 105,
                                  child: Text(
                                    dateFormatted,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                // Proveedor + Documento / Almacén
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        po.supplierName,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        po.documentType.isNotEmpty
                                            ? '${po.documentType} ${po.documentNumber ?? ""}'
                                            : (po.warehouseName ?? 'Almacén Principal'),
                                        style: const TextStyle(
                                          fontSize: 10.5,
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
                                  width: 105,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildStatusBadge(po.status),
                                  ),
                                ),

                                // Pago / Deuda
                                SizedBox(
                                  width: 125,
                                  child: _buildPaymentBadge(po),
                                ),

                                // Total
                                SizedBox(
                                  width: 95,
                                  child: Text(
                                    'S/ ${po.totalAmount.toStringAsFixed(2)}',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),

                                // Chevron
                                const SizedBox(
                                  width: 40,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
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
