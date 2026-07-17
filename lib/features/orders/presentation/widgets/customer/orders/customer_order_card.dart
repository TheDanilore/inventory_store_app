import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/orders/customer_order_detail_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CustomerOrderCard extends StatefulWidget {
  final OrderEntity order;
  final bool isProcessing;
  final VoidCallback onReorder;

  const CustomerOrderCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onReorder,
  });

  @override
  State<CustomerOrderCard> createState() => _CustomerOrderCardState();
}

class _CustomerOrderCardState extends State<CustomerOrderCard> {
  bool _isLoadingDetails = false;

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.order.createdAt ?? DateTime.now();
    final hasPoints =
        (widget.order.pointsUsed) > 0 || (widget.order.pointsEarned) > 0;
    final statusColor = _statusColor(widget.order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap:
              (widget.isProcessing || _isLoadingDetails)
                  ? null
                  : () => _showOrderDetails(widget.order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido #${widget.order.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('dd MMM yyyy · HH:mm').format(createdAt),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.store_outlined,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.order.warehouseName ?? 'Tienda',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${widget.order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _statusBadge(widget.order.status),
                      ],
                    ),
                  ],
                ),

                if (hasPoints) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.goldLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          size: 14,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          [
                            if ((widget.order.pointsUsed) > 0)
                              '−${widget.order.pointsUsed} usadas',
                            if ((widget.order.pointsEarned) > 0)
                              '+${widget.order.pointsEarned} ganadas',
                          ].join('  ·  '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A6300),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        label: 'Ver detalle',
                        icon: Icons.receipt_long_outlined,
                        onTap:
                            (widget.isProcessing || _isLoadingDetails)
                                ? null
                                : () => _showOrderDetails(widget.order),
                        filled: false,
                        isProcessing: _isLoadingDetails,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _actionButton(
                        label: 'Repetir pedido',
                        icon: Icons.add_shopping_cart_rounded,
                        onTap: widget.isProcessing ? null : widget.onReorder,
                        filled: true,
                        isProcessing: widget.isProcessing,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(OrderEntity order) async {
    setState(() => _isLoadingDetails = true);
    try {
      final cubit = context.read<OrdersCubit>();
      final items = await cubit.fetchOrderItems(order.id);

      if (!mounted) return;
      setState(() => _isLoadingDetails = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => CustomerOrderDetailSheet(order: order, items: items),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingDetails = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required bool filled,
    required bool isProcessing,
  }) {
    if (filled) {
      return SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon:
              isProcessing
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Icon(icon, size: 16),
          label: Text(
            isProcessing ? 'Cargando...' : label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon:
              isProcessing
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                  : Icon(icon, size: 16),
          label: Text(
            isProcessing ? 'Cargando...' : label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(
              color:
                  isProcessing
                      ? AppColors.border.withValues(alpha: 0.5)
                      : AppColors.border,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'PAID':
        return Colors.blue;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _statusBadge(String status) {
    String text;
    switch (status) {
      case 'PENDING':
        text = 'Pendiente';
        break;
      case 'PAID':
        text = 'Pagado';
        break;
      case 'DELIVERED':
        text = 'Entregado';
        break;
      case 'CANCELLED':
        text = 'Cancelado';
        break;
      default:
        text = status;
    }
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
