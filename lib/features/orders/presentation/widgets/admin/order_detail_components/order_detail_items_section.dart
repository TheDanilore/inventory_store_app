import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_section_card.dart';

class OrderDetailItemCard extends StatefulWidget {
  final OrderItemEntity item;
  final bool isEditing;
  final bool usesBatches;
  final List<Map<String, dynamic>> batches;
  final List<BatchAssignmentModel>? batchAssignments;
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
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
    this.onQuantityTap,
    this.onEditBatches,
  });

  @override
  State<OrderDetailItemCard> createState() => _OrderDetailItemCardState();
}

class _OrderDetailItemCardState extends State<OrderDetailItemCard> {
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant OrderDetailItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _quantityController.text = widget.item.quantity.toString();
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

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
    final subtotal = widget.item.subtotal;
    final imageUrl = widget.item.displayImageUrl;

    final bool canEditBatches =
        widget.onEditBatches != null && widget.usesBatches;
    final bool hasBatchOverride =
        canEditBatches && widget.batchAssignments != null;
    final activeBatches =
        hasBatchOverride
            ? widget.batchAssignments!.where((b) => b.assigned > 0).toList()
            : <BatchAssignmentModel>[];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
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
                              color: AppColors.teal.withValues(alpha: 0.08),
                              child: const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.teal,
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
                    widget.item.productName ?? 'Producto sin nombre',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.item.variantLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${widget.item.sku ?? 'N/A'}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'P. unit: S/ ${widget.item.appliedPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),

                  if (canEditBatches) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: widget.onEditBatches,
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
                  ] else if (widget.batches.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          widget.batches.map((b) {
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
                                color: AppColors.teal.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.teal.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.inventory_2_rounded,
                                    size: 10,
                                    color: AppColors.tealDark,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.tealDark,
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
                if (widget.isEditing)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop =
                          MediaQuery.of(context).size.width > 700;

                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: widget.onDecrease,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(24),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isDesktop)
                              SizedBox(
                                width: 44,
                                child: TextField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 6,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: widget.onQuantityChanged,
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: widget.onQuantityTap,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _quantityController.text,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.edit_rounded,
                                        size: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            InkWell(
                              onTap: widget.onIncrease,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(24),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'x${widget.item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'S/ ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
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
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: AppColors.teal, size: 22),
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
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantityChanged,
    this.onQuantityTap,
    this.onEditBatches,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Productos del Pedido',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '${items.length} ${items.length == 1 ? 'item' : 'items'}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin items registrados.',
                  style: TextStyle(color: AppColors.textMuted),
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
