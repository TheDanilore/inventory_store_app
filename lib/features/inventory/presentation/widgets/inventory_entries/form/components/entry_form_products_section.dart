import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/entry_item_card.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/form/components/entry_form_section_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_order_items_table.dart';

/// Sección de productos a ingresar con soporte Desktop (tabla de alta densidad) y Mobile (tarjetas táctiles).
class EntryFormProductsSection extends StatelessWidget {
  final bool isDesktop;
  final String? purchaseOrderId;
  final VoidCallback onAddNewRow;
  final VoidCallback onScanBarcode;
  final VoidCallback onClearDraft;
  final void Function(int index, InventoryEntryItemEntity item) onEditBatch;
  final void Function(int index) onRemoveItem;
  final void Function(int index, double qty) onUpdateQuantity;
  final void Function(int index, double cost) onUpdateCost;

  const EntryFormProductsSection({
    super.key,
    this.isDesktop = false,
    this.purchaseOrderId,
    required this.onAddNewRow,
    required this.onScanBarcode,
    required this.onClearDraft,
    required this.onEditBatch,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onUpdateCost,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return BlocSelector<
        InventoryEntryFormCubit,
        InventoryEntryFormState,
        List<InventoryEntryItemEntity>
      >(
        selector: (state) => state.items,
        builder: (context, items) {
          return PurchaseOrderItemsTable(
            items: items,
            title: 'Productos a ingresar',
            emptyTitle: 'Aún no hay productos',
            emptyMessage:
                'Agrega los productos que vas a ingresar a tu almacén.',
            showFooter: false,
            onRemoveItem: onRemoveItem,
            onUpdateQuantity: onUpdateQuantity,
            onUpdateCost: onUpdateCost,
            onAddNewRow: onAddNewRow,
            onScanBarcode: onScanBarcode,
            onEditBatch: (index) {
              if (index < items.length) {
                onEditBatch(index, items[index]);
              }
            },
          );
        },
      );
    }

    return EntryFormSectionCard(
      child: BlocSelector<
        InventoryEntryFormCubit,
        InventoryEntryFormState,
        List<InventoryEntryItemEntity>
      >(
        selector: (state) => state.items,
        builder: (context, items) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: EntryFormSectionTitle(
                      icon: Icons.inventory_2_rounded,
                      title:
                          items.isEmpty
                              ? 'Productos'
                              : 'Productos (${items.length})',
                    ),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Escanear código',
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      onPressed: onScanBarcode,
                    ),
                    const SizedBox(width: 4),
                    FilledButton.tonalIcon(
                      onPressed: onAddNewRow,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Agregar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (purchaseOrderId == null)
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
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child:
                    items.isEmpty
                        ? _buildEmptyProducts(context)
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            return EntryItemCard(
                              key: ValueKey(
                                'entry_item_${item.productId}_${item.variantId}_${item.batchNumber}_$index',
                              ),
                              item: item,
                              onUpdateQuantity:
                                  (qty) => onUpdateQuantity(index, qty),
                              onUpdateCost: (cost) => onUpdateCost(index, cost),
                              onEditBatch:
                                  item.usesBatches
                                      ? () => onEditBatch(index, item)
                                      : null,
                              onRemove: () => onRemoveItem(index),
                            );
                          }),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyProducts(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.move_to_inbox_rounded,
              size: 26,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aún no hay productos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Agrega los productos que vas a ingresar a tu almacén.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Escanear código'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
