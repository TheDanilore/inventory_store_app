import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/inventory_entry_model.dart';
import 'package:inventory_store_app/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class InventoryEntryDetailSheet extends StatefulWidget {
  final InventoryEntryModel entry;
  final Future<List<InventoryEntryItemModel>> Function() loadItems;

  const InventoryEntryDetailSheet({
    super.key,
    required this.entry,
    required this.loadItems,
  });

  @override
  State<InventoryEntryDetailSheet> createState() =>
      _InventoryEntryDetailSheetState();
}

class _InventoryEntryDetailSheetState extends State<InventoryEntryDetailSheet> {
  List<InventoryEntryItemModel>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.loadItems().then((items) {
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final entry = widget.entry;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder:
          (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.supplierName ?? 'Sin proveedor',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              entry.createdAt != null
                                  ? fmt.format(entry.createdAt!.toLocal())
                                  : '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            entry.warehouseName ?? 'Sin almacén',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Items
                Expanded(
                  child:
                      _loading
                          ? const _ItemsSkeleton()
                          : ListView.separated(
                            controller: controller,
                            padding: const EdgeInsets.all(20),
                            itemCount: _items!.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final item = _items![i];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // ── IMAGEN EN CACHÉ ──────────────────────────
                                    Container(
                                      width: 48,
                                      height: 48,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child:
                                            item.imageUrl != null &&
                                                    item.imageUrl!.isNotEmpty
                                                ? CachedNetworkImage(
                                                  imageUrl: item.imageUrl!,
                                                  fit: BoxFit.cover,
                                                  placeholder:
                                                      (
                                                        context,
                                                        url,
                                                      ) => Container(
                                                        color:
                                                            Colors.grey.shade50,
                                                        child: const Center(
                                                          child: SizedBox(
                                                            width: 16,
                                                            height: 16,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                  errorWidget:
                                                      (
                                                        context,
                                                        url,
                                                        error,
                                                      ) => Container(
                                                        color:
                                                            Colors.grey.shade50,
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          size: 20,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                        ),
                                                      ),
                                                )
                                                : Container(
                                                  color: Colors.grey.shade50,
                                                  child: Icon(
                                                    Icons.inventory_2_outlined,
                                                    size: 22,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    // ── TEXTOS ───────────────────────────────────
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            item.usesBatches
                                                ? '${item.variantAttrs} · Lote: ${item.batchNumber}'
                                                : item.variantAttrs,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          if (item.usesBatches &&
                                              item.expiryDate != null)
                                            Text(
                                              'Vence: ${DateFormat('dd/MM/yyyy').format(item.expiryDate!)}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // ── PRECIOS ──────────────────────────────────
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${item.quantity.toStringAsFixed(0)} uds.',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'S/ ${item.unitCost.toStringAsFixed(2)} c/u',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          'S/ ${item.subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }
}

class _ItemsSkeleton extends StatelessWidget {
  const _ItemsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const AppShimmer(width: 48, height: 48, borderRadius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmer(width: 120, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    AppShimmer(width: 80, height: 10, borderRadius: 4),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  AppShimmer(width: 50, height: 14, borderRadius: 4),
                  SizedBox(height: 6),
                  AppShimmer(width: 70, height: 10, borderRadius: 4),
                  SizedBox(height: 6),
                  AppShimmer(width: 60, height: 14, borderRadius: 4),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
