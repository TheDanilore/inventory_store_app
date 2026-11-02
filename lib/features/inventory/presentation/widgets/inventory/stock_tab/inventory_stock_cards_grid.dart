import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_card.dart';

class InventoryStockCardsSliverGrid extends StatelessWidget {
  final List<InventoryStockItem> items;
  final InventoryStockItem? selectedItem;
  final ValueChanged<InventoryStockItem> onQuickView;
  final ValueChanged<InventoryStockItem> onStockEntry;
  final ValueChanged<InventoryStockItem> onStockExit;

  const InventoryStockCardsSliverGrid({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onQuickView,
    required this.onStockEntry,
    required this.onStockExit,
  });

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 440,
        mainAxisExtent: 220,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      delegate: SliverChildBuilderDelegate((context, i) {
        final item = items[i];
        final isSelected =
            selectedItem != null &&
            ((selectedItem!.variantId.isNotEmpty &&
                    selectedItem!.variantId == item.variantId) ||
                (selectedItem!.productId == item.productId &&
                    selectedItem!.variantId == item.variantId));
        return RepaintBoundary(
          child: InventoryStockCard(
            item: item,
            isSelected: isSelected,
            onTap: () => onQuickView(item),
            onStockEntry: () => onStockEntry(item),
            onStockExit: () => onStockExit(item),
          ),
        );
      }, childCount: items.length),
    );
  }
}
