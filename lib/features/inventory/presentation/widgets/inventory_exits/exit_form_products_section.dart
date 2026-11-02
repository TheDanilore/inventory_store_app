import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exit_items_table.dart';

class ExitFormProductsSection extends StatelessWidget {
  final bool isDesktop;
  final VoidCallback onAddProduct;
  final VoidCallback onScanBarcode;
  final VoidCallback onClearDraft;
  final void Function(int index) onRemoveItem;

  const ExitFormProductsSection({
    super.key,
    required this.isDesktop,
    required this.onAddProduct,
    required this.onScanBarcode,
    required this.onClearDraft,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: BlocSelector<
        InventoryExitFormCubit,
        InventoryExitFormState,
        List<ExitItemUI>
      >(
        selector: (state) => state.items,
        builder: (context, items) {
          final cubit = context.read<InventoryExitFormCubit>();

          if (isDesktop) {
            return InventoryExitItemsTable(
              items: items,
              onRemoveItem: onRemoveItem,
              onUpdateQuantity: (index, qty) => cubit.updateQuantity(index, qty),
              onAddNewRow: onAddProduct,
              onScanBarcode: onScanBarcode,
            );
          }

          final compact = MediaQuery.sizeOf(context).width < 600;

          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(compact ? 16 : 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              items.isEmpty
                                  ? 'Productos a retirar'
                                  : 'Productos a retirar (${items.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                        onPressed: onAddProduct,
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
                            (_) => const [
                              PopupMenuItem(
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
                          ? _EmptyProductsView(
                            onAddProduct: onAddProduct,
                            onScanBarcode: onScanBarcode,
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(items.length, (index) {
                              final item = items[index];
                              return InventoryExitItemCard(
                                key: ValueKey(
                                  'exit_item_${item.product.id}_${item.variant.id}_${exitRowBatchKey(item)}_$index',
                                ),
                                item: item,
                                onUpdateQuantity:
                                    (qty) =>
                                        cubit.updateQuantity(index, qty),
                                onRemove: () => onRemoveItem(index),
                              );
                            }),
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyProductsView extends StatelessWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onScanBarcode;

  const _EmptyProductsView({
    required this.onAddProduct,
    required this.onScanBarcode,
  });

  @override
  Widget build(BuildContext context) {
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
              Icons.outbox_rounded,
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
            'Agrega los productos que vas a dar de baja de tu inventario.',
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
                onPressed: onAddProduct,
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
