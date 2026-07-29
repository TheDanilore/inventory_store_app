import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class POCard extends StatelessWidget {
  final PurchaseOrderModel po;
  final VoidCallback onTap;
  final bool isSelected;

  const POCard({
    super.key,
    required this.po,
    required this.onTap,
    this.isSelected = false,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'SENT':
        return Colors.blue.shade600;
      case 'PARTIAL':
        return Colors.amber.shade700;
      case 'RECEIVED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.schedule_rounded;
      case 'SENT':
        return Icons.local_shipping_rounded;
      case 'PARTIAL':
        return Icons.pie_chart_outline_rounded;
      case 'RECEIVED':
        return Icons.task_alt_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'SENT':
        return 'Enviado';
      case 'PARTIAL':
        return 'Parcial';
      case 'RECEIVED':
        return 'Recibido';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Color _paymentStatusColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'PENDING':
        return AppColors.danger;
      case 'PARTIAL':
        return Colors.amber.shade800;
      case 'PAID':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _paymentStatusIcon(String paymentStatus) {
    switch (paymentStatus) {
      case 'PENDING':
        return Icons.money_off_csred_rounded;
      case 'PARTIAL':
        return Icons.pie_chart_outline_rounded;
      case 'PAID':
        return Icons.verified_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  String _paymentStatusLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'PENDING':
        return 'Por pagar';
      case 'PARTIAL':
        return 'Pago parcial';
      case 'PAID':
        return 'Pagado';
      default:
        return paymentStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(po.status);
    final isCancelled = po.status == 'CANCELLED';
    final debt =
        isCancelled
            ? 0.0
            : (po.totalAmount - po.amountPaid).clamp(0.0, double.infinity);
    final isUnpaid = !isCancelled && po.paymentStatus != 'PAID' && debt > 0;
    final shortCode =
        '#${po.id.length >= 8 ? po.id.substring(0, 8).toUpperCase() : po.id.toUpperCase()}';

    return Semantics(
      label:
          '${po.supplierName}, ${_statusLabel(po.status)}, '
          'S/ ${po.totalAmount.toStringAsFixed(2)}, ${po.itemCount} productos',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey.shade200 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.textPrimary : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isSelected
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.02),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Acento lateral de estado ──
                  Container(width: 4, color: statusColor),
                  // ── Contenido ──────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  po.supplierName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _Pill(
                                icon: _statusIcon(po.status),
                                label: _statusLabel(po.status),
                                color: statusColor,
                              ),
                              if (isUnpaid) ...[
                                const SizedBox(width: 4),
                                _Pill(
                                  icon: _paymentStatusIcon(po.paymentStatus),
                                  label: _paymentStatusLabel(po.paymentStatus),
                                  color: _paymentStatusColor(po.paymentStatus),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$shortCode • ${po.itemCount} ${po.itemCount == 1 ? 'producto' : 'productos'}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                      'es',
                                    ).format(po.createdAt),
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'S/ ${po.totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color:
                                          isCancelled
                                              ? AppColors.textMuted
                                              : AppColors.primary,
                                      decoration:
                                          isCancelled
                                              ? TextDecoration.lineThrough
                                              : null,
                                    ),
                                  ),
                                  if (isCancelled) ...[
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Anulado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ] else if (isUnpaid) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Deuda: S/ ${debt.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ] else if (po.paymentStatus == 'PAID') ...[
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Pagado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
