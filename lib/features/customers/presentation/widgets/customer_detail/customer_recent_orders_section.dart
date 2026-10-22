import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_section_card.dart';

class CustomerRecentOrdersSection extends StatelessWidget {
  final List<RecentOrderEntity> orders;
  final String customerId;
  final String customerName;
  final VoidCallback onViewAllOrders;

  const CustomerRecentOrdersSection({
    super.key,
    required this.orders,
    required this.customerId,
    required this.customerName,
    required this.onViewAllOrders,
  });

  @override
  Widget build(BuildContext context) {
    return CustomerSectionCard(
      title: 'Pedidos recientes',
      icon: Icons.receipt_long_rounded,
      child:
          orders.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Sin pedidos aún',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
              : Column(
                children: [
                  ...orders.take(5).toList().asMap().entries.map((entry) {
                    return _OrderRow(
                      order: entry.value,
                      isLast:
                          entry.key ==
                          (orders.length > 5 ? 4 : orders.length - 1),
                    );
                  }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onViewAllOrders,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Ver todos los pedidos →'),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final RecentOrderEntity order;
  final bool isLast;
  const _OrderRow({required this.order, this.isLast = false});

  bool get _isCancelled => order.status.toUpperCase() == 'CANCELLED';
  bool get _isPendingDraft => order.status.toUpperCase() == 'PENDING';
  bool get _isCompleted => order.status.toUpperCase() == 'COMPLETED';

  Color get _statusColor {
    if (_isCancelled) return AppColors.danger;
    if (_isPendingDraft) return Colors.purple;
    switch (order.paymentStatus) {
      case 'PAID':
        return AppColors.success;
      case 'PENDING':
        return Colors.orange;
      case 'PARTIAL':
        return Colors.blue;
      default:
        return AppColors.textMuted;
    }
  }

  String get _statusLabel {
    if (_isCancelled) return 'Cancelado';
    if (_isPendingDraft) return 'Borrador';
    switch (order.paymentStatus) {
      case 'PAID':
        return 'Pagado';
      case 'PENDING':
        return 'Por Pagar';
      case 'PARTIAL':
        return 'Parcial';
      default:
        return order.paymentStatus;
    }
  }

  String _methodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'EFECTIVO':
        return 'Efectivo';
      case 'CRÉDITO':
        return 'Crédito';
      case 'YAPE':
        return 'Yape';
      case 'TRANSFERENCIA':
        return 'Transferencia';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPending =
        _isCompleted &&
        order.paymentStatus != 'PAID' &&
        order.pendingAmount > 0;
    final hasDiscount = order.discountAmount > 0;
    final shortId =
        order.id.length >= 8
            ? order.id.substring(0, 8).toUpperCase()
            : order.id.toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/orders?selectedId=${order.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        _isCancelled
                            ? AppColors.dangerLight
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    _isCancelled
                        ? Icons.remove_shopping_cart_rounded
                        : Icons.receipt_long_rounded,
                    size: 18,
                    color: _isCancelled ? AppColors.danger : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#$shortId',
                            style: TextStyle(
                              color:
                                  _isCancelled
                                      ? AppColors.textMuted
                                      : AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              fontFamily: 'monospace',
                              decoration:
                                  _isCancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${DateFormat('d MMM yyyy', 'es').format(order.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              _methodLabel(order.paymentMethod),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (!_isCancelled && order.pointsEarned > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '+${order.pointsEarned} pts',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (!_isCancelled && order.pointsUsed > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '-${order.pointsUsed} pts',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hasDiscount && !_isCancelled)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Descuento aplicado: S/ ${order.discountAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (hasPending && order.dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Vence: ${DateFormat('d MMM yyyy', 'es').format(order.dueDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  order.dueDate!.isBefore(DateTime.now())
                                      ? AppColors.danger
                                      : Colors.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'S/ ${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: -0.2,
                        decoration:
                            _isCancelled ? TextDecoration.lineThrough : null,
                        color:
                            _isCancelled
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: _statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (hasPending) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Debe S/ ${order.pendingAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
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
