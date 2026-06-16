import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/providers/customer/customer_orders_provider.dart';

class CustomerOrderDetailSheet extends StatefulWidget {
  final OrderModel order;

  const CustomerOrderDetailSheet({super.key, required this.order});

  @override
  State<CustomerOrderDetailSheet> createState() =>
      _CustomerOrderDetailSheetState();
}

class _CustomerOrderDetailSheetState extends State<CustomerOrderDetailSheet> {
  List<OrderItemModel>? _items;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final provider = context.read<CustomerOrdersProvider>();
      final items = await provider.fetchOrderItems(widget.order.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalle del Pedido',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${widget.order.id.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child:
                _isLoading
                    ? const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                    : _error != null
                    ? Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      itemCount: _items!.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        return _buildItemCard(_items![index]);
                      },
                    ),
          ),

          if (!_isLoading && _items != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Subtotal',
                      'S/ ${(widget.order.totalAmount + widget.order.discountAmount).toStringAsFixed(2)}',
                    ),
                    if (widget.order.discountAmount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Descuento',
                        '-S/ ${widget.order.discountAmount.toStringAsFixed(2)}',
                        isDiscount: true,
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'S/ ${widget.order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDiscount ? Colors.red : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDiscount ? Colors.red : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(OrderItemModel item) {
    String attributesStr = '';

    if (item.attributes.isNotEmpty) {
      attributesStr = item.attributes.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' • ');
    }

    String? imageUrl = item.displayImageUrl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child:
              imageUrl != null
                  ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                  )
                  : const Icon(Icons.inventory_2_outlined, color: Colors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName ?? 'Producto Desconocido',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (attributesStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  attributesStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.quantity} un. x S/ ${item.appliedPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'S/ ${(item.quantity * item.appliedPrice).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
