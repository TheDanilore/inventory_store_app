import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'customer_section_card.dart';

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

  Color get _statusColor {
    if (_isCancelled) return AppColors.danger;
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
    switch (order.paymentStatus) {
      case 'PAID':
        return 'Pagado';
      case 'PENDING':
        return 'Pendiente';
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
      case 'CREDITO':
      case 'CRÃ‰DITO':
        return 'CrÃ©dito';
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
        !_isCancelled &&
        order.paymentStatus != 'PAID' &&
        order.pendingAmount > 0;
    final hasDiscount = order.discountAmount > 0;
    final shortId =
        order.id.length >= 8
            ? order.id.substring(0, 8).toUpperCase()
            : order.id.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isCancelled ? AppColors.dangerLight : AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCancelled
                      ? Icons.remove_shopping_cart_rounded
                      : Icons.shopping_bag_outlined,
                  size: 16,
                  color: _isCancelled ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '#$shortId ',
                            style: TextStyle(
                              color:
                                  _isCancelled
                                      ? AppColors.textMuted
                                      : AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text:
                                'â€¢ ${DateFormat('d MMM yyyy', 'es').format(order.createdAt)}',
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        decoration:
                            _isCancelled ? TextDecoration.lineThrough : null,
                        color:
                            _isCancelled
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          _methodLabel(order.paymentMethod),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (!_isCancelled && order.pointsEarned > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '+${order.pointsEarned}pts',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (!_isCancelled && order.pointsUsed > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '-${order.pointsUsed}pts',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (hasDiscount && !_isCancelled)
                      Text(
                        'Descuento: S/ ${order.discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                        ),
                      ),
                    if (hasPending && order.dueDate != null)
                      Text(
                        'Vence: ${DateFormat('d MMM yyyy', 'es').format(order.dueDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              order.dueDate!.isBefore(DateTime.now())
                                  ? AppColors.danger
                                  : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/ ${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      decoration:
                          _isCancelled ? TextDecoration.lineThrough : null,
                      color:
                          _isCancelled
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasPending)
                    Text(
                      'Debe S/ ${order.pendingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Divider(height: 1, color: AppColors.border),
            ),
        ],
      ),
    );
  }
}
