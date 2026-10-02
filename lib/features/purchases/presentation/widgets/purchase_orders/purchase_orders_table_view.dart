import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';

class PurchaseOrdersTableView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTableWidth = 920.0;
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
                          width: 130,
                          child: Text(
                            'PAGO / ESTADO',
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
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final po = orders[index];
                      final isSelected = selectedOrder?.id == po.id;

                      return _PurchaseOrderTableRow(
                        key: ValueKey(po.id),
                        po: po,
                        isSelected: isSelected,
                        onSelect: () => onSelectOrder(po),
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
// FILA AISLADA CON HOVER LOCAL
// ─────────────────────────────────────────────────────────────────────────────

class _PurchaseOrderTableRow extends StatefulWidget {
  final PurchaseOrderModel po;
  final bool isSelected;
  final VoidCallback onSelect;

  const _PurchaseOrderTableRow({
    super.key,
    required this.po,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  State<_PurchaseOrderTableRow> createState() => _PurchaseOrderTableRowState();
}

class _PurchaseOrderTableRowState extends State<_PurchaseOrderTableRow> {
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
          color: AppColors.successLight.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 11, color: AppColors.successDark),
            SizedBox(width: 4),
            Text(
              'Pagado',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.successDark,
              ),
            ),
          ],
        ),
      );
    } else if (isCredit && debt > 0) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.warningLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.warningDark,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Por Pagar: S/ ${debt.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.warningDark,
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
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: const Text(
          'Pendiente',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    } else {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: AppColors.warningLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Text(
          debt > 0 ? 'Por Pagar: S/ ${debt.toStringAsFixed(2)}' : 'Pendiente',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.warningDark,
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
    final po = widget.po;
    final isSelected = widget.isSelected;

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
                ? AppColors.tealLight.withValues(alpha: 0.45)
                : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.teal : const Color(0x000D9488),
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
              // 1. ID Orden
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

              // 2. Fecha / Hora
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

              // 3. Proveedor / Documento
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      po.supplierName.isNotEmpty ? po.supplierName : 'Sin Proveedor',
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
                      docSubtitle,
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

              // 4. Estado
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(po.status),
                ),
              ),

              // 5. Pago / Deuda
              SizedBox(
                width: 130,
                child: _buildPaymentBadge(po),
              ),

              // 6. Total
              SizedBox(
                width: 110,
                child: Text(
                  'S/ ${po.totalAmount.toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // 7. Acciones
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
                      tooltip: 'Ver detalle',
                      onPressed: widget.onSelect,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: _isHovered ? AppColors.tealDark : AppColors.textMuted,
                      ),
                      tooltip: 'Abrir orden',
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
