import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_form_item_tile.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_form_summary_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_order_items_table.dart';
import 'po_form_section_widgets.dart';

class POFormProductsSection extends StatelessWidget {
  final List<InventoryEntryItemEntity> items;
  final bool isDesktop;
  final bool isEditing;
  final String currencyCode;
  final double exchangeRate;
  final ValueChanged<int> onRemoveItem;
  final void Function(int index, double quantity) onUpdateQuantity;
  final void Function(int index, double cost) onUpdateCost;
  final VoidCallback onAddNewRow;
  final VoidCallback onScanBarcode;
  final VoidCallback onClearDraft;

  const POFormProductsSection({
    super.key,
    required this.items,
    this.isDesktop = false,
    required this.isEditing,
    required this.currencyCode,
    required this.exchangeRate,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onUpdateCost,
    required this.onAddNewRow,
    required this.onScanBarcode,
    required this.onClearDraft,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return PurchaseOrderItemsTable(
        items: items,
        onRemoveItem: onRemoveItem,
        onUpdateQuantity: onUpdateQuantity,
        onUpdateCost: onUpdateCost,
        onAddNewRow: onAddNewRow,
        onScanBarcode: onScanBarcode,
      );
    }

    return POFormSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: POFormSectionTitle(
                  icon: Icons.inventory_2_rounded,
                  title: 'Productos a Pedir',
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Escanear código',
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: onScanBarcode,
                  ),
                  TextButton.icon(
                    onPressed: onAddNewRow,
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Agregar'),
                  ),
                  if (items.isNotEmpty && !isEditing)
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onSelected: (value) {
                        if (value == 'clear') onClearDraft();
                      },
                      itemBuilder:
                          (_) => [
                            const PopupMenuItem(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_sweep_rounded,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Descartar todo',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 52,
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tu orden está vacía',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Agrega los productos que necesitas pedir a tu proveedor',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onScanBarcode,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                        ),
                        label: const Text('Escanear código'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onAddNewRow,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Agregar producto'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Column(
              children:
                  items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return POFormItemTile(
                      item: item,
                      onUpdateQuantity:
                          (newQty) => onUpdateQuantity(index, newQty),
                      onUpdateCost: (newCost) => onUpdateCost(index, newCost),
                      onRemove: () => onRemoveItem(index),
                    );
                  }).toList(),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            child:
                items.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: POFormSummaryCard(
                        items: items,
                        currencyCode: currencyCode,
                        exchangeRate: exchangeRate,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
