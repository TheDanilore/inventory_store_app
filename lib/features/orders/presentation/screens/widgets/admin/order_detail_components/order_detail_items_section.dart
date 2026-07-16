import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/widgets/admin/order_detail_components/order_detail_section_card.dart';

class OrderDetailItemCard extends StatelessWidget {
  final OrderItemEntity item;
  final bool isEditing;
  final bool usesBatches;
  final List<Map<String, dynamic>> batches;
  final List<BatchAssignmentModel>? batchAssignments;
  final TextEditingController quantityController;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onQuantityChanged;
  final VoidCallback? onQuantityTap;
  final VoidCallback? onEditBatches;

  const OrderDetailItemCard({
    super.key,
    required this.item,
    required this.isEditing,
    required this.usesBatches,
    this.batches = const [],
    this.batchAssignments,
    required this.quantityController,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
    this.onQuantityTap,
    this.onEditBatches,
  });

  String _formatExpiry(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = item.subtotal;
    final imageUrl = item.displayImageUrl;

    final bool canEditBatches = onEditBatches != null && usesBatches;
    final bool hasBatchOverride = canEditBatches && batchAssignments != null;
    final activeBatches =
        hasBatchOverride
            ? batchAssignments!.where((b) => b.assigned > 0).toList()
            : <BatchAssignmentModel>[];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child:
                  imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              width: 52,
                              height: 52,
                              color: Colors.teal.withValues(alpha: 0.1),
                              child: const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.teal,
                                  ),
                                ),
                              ),
                            ),
                        errorWidget: (_, _, _) => _placeholderIcon(),
                      )
                      : _placeholderIcon(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName ?? 'Producto sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.variantLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU: ${item.sku ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'P. unit: S/ ${item.appliedPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),

                  if (canEditBatches) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onEditBatches,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              hasBatchOverride && activeBatches.isNotEmpty
                                  ? AppColors.teal.withValues(alpha: 0.08)
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                hasBatchOverride && activeBatches.isNotEmpty
                                    ? AppColors.teal.withValues(alpha: 0.3)
                                    : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasBatchOverride && activeBatches.isNotEmpty
                                  ? Icons.inventory_2_rounded
                                  : Icons.edit_note_rounded,
                              size: 11,
                              color:
                                  hasBatchOverride && activeBatches.isNotEmpty
                                      ? AppColors.teal
                                      : Colors.orange.shade800,
                            ),
                            const SizedBox(width: 4),
                            if (hasBatchOverride && activeBatches.isNotEmpty)
                              Flexible(
                                child: Text(
                                  activeBatches
                                      .map(
                                        (b) =>
                                            '${b.assigned}u · ${b.batchNumber}${b.expiryDate != null ? ' (vto ${b.expiryLabel})' : ''}',
                                      )
                                      .join(' + '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.tealDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              Flexible(
                                child: Text(
                                  'FEFO automático · Toca para editar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_rounded,
                              size: 10,
                              color:
                                  hasBatchOverride && activeBatches.isNotEmpty
                                      ? AppColors.teal
                                      : Colors.orange.shade800,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (batches.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          batches.map((b) {
                            final batchNumber =
                                b['batch_number'] as String? ?? '';
                            final qty = b['quantity'] as int? ?? 0;
                            final expiry = _formatExpiry(b['expiry_date']);
                            final label =
                                expiry.isNotEmpty
                                    ? '${qty}u · $batchNumber (vto $expiry)'
                                    : '${qty}u · $batchNumber';
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.teal.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_rounded,
                                    size: 10,
                                    color: Colors.teal.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isEditing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onDecrease,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(24),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onQuantityTap,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 32),
                            alignment: Alignment.center,
                            child: Text(
                              quantityController.text,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onIncrease,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(24),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'x${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 6),
                Text(
                  'S/ ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.teal),
    );
  }
}

class OrderDetailItemsSection extends StatelessWidget {
  final List<OrderItemEntity> items;
  final bool isLoading;
  final bool isEditing;
  final bool isLocked;
  final Map<String, List<Map<String, dynamic>>> batchesByVariant;
  final Map<String, bool> usesBatchesMap;
  final Map<String, List<BatchAssignmentModel>> batchOverrides;
  final List<TextEditingController> quantityControllers;
  final void Function(int index) onDecrease;
  final void Function(int index) onIncrease;
  final void Function(int index, String value) onQuantityChanged;
  final void Function(int index)? onQuantityTap;
  final void Function(OrderItemEntity item)? onEditBatches;

  const OrderDetailItemsSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.isEditing,
    this.isLocked = false,
    this.batchesByVariant = const {},
    required this.usesBatchesMap,
    this.batchOverrides = const {},
    required this.quantityControllers,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
    this.onQuantityTap,
    this.onEditBatches,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Items (${items.length})',
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin items registrados.',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final batches = batchesByVariant[item.variantId ?? ''] ?? [];
                  final usesBatches =
                      usesBatchesMap[item.variantId ?? ''] ?? false;

                  return OrderDetailItemCard(
                    item: item,
                    isEditing: isEditing && !isLocked,
                    usesBatches: usesBatches,
                    batches: batches,
                    batchAssignments: batchOverrides[item.id],
                    quantityController: quantityControllers[index],
                    onDecrease: () => onDecrease(index),
                    onIncrease: () => onIncrease(index),
                    onQuantityChanged:
                        (value) => onQuantityChanged(index, value),
                    onQuantityTap:
                        onQuantityTap != null
                            ? () => onQuantityTap!(index)
                            : null,
                    onEditBatches:
                        (onEditBatches != null && !isLocked)
                            ? () => onEditBatches!(item)
                            : null,
                  );
                },
              ),
    );
  }
}
