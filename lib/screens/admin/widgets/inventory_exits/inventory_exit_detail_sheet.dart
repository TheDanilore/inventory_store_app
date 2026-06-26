import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/inventory_exit_model.dart';
import 'package:inventory_store_app/models/inventory_exit_item_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/shared/widgets/detail_sheet_header.dart';
import 'package:inventory_store_app/shared/widgets/product_item_card.dart';

class InventoryExitDetailSheet extends StatefulWidget {
  final InventoryExitModel exitData;
  final Future<List<InventoryExitItemModel>> Function() loadItems;
  final bool isBottomSheet;

  const InventoryExitDetailSheet({
    super.key,
    required this.exitData,
    required this.loadItems,
    this.isBottomSheet = true,
  });

  @override
  State<InventoryExitDetailSheet> createState() =>
      _InventoryExitDetailSheetState();
}

class _InventoryExitDetailSheetState extends State<InventoryExitDetailSheet> {
  List<InventoryExitItemModel>? _items;

  @override
  void initState() {
    super.initState();
    widget.loadItems().then((value) {
      if (mounted) setState(() => _items = value);
    });
  }

  Color _reasonColor(String reason) {
    final r = reason.toUpperCase();
    if (r.contains('MERMA') ||
        r.contains('DAÑO') ||
        r.contains('VENCIMIENTO')) {
      return AppColors.danger;
    }
    if (r.contains('ROBO') || r.contains('PÉRDIDA')) {
      return Colors.red.shade900;
    }
    if (r.contains('CONSUMO') || r.contains('USO INTERNO')) {
      return Colors.blue.shade600;
    }
    if (r.contains('AJUSTE')) return Colors.orange.shade600;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.exitData.reason ?? '';
    final reasonColor = _reasonColor(reason);

    return Container(
      height:
          widget.isBottomSheet
              ? MediaQuery.of(context).size.height * 0.85
              : null,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius:
            widget.isBottomSheet
                ? const BorderRadius.vertical(top: Radius.circular(28))
                : BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header compartido ──────────────────────────────────────
          DetailSheetHeader(
            title: 'Detalle de Salida',
            showDragHandle: widget.isBottomSheet,
            trailing:
                reason.isNotEmpty
                    ? StatusPill(
                      label: reason,
                      color: reasonColor,
                      icon: Icons.info_outline_rounded,
                    )
                    : null,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Card de metadata del registro ────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ALMACÉN ORIGEN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.exitData.warehouseName ?? 'Desconocido',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        if (widget.exitData.notes != null &&
                            widget.exitData.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'NOTAS / JUSTIFICACIÓN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.exitData.notes!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],

                        const Divider(height: 24, color: AppColors.border),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Costo total con animación de conteo
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'COSTO TOTAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: widget.exitData.totalCost,
                                  ),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder:
                                      (_, value, _) => Text(
                                        'S/ ${value.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'FECHA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  widget.exitData.createdAt != null
                                      ? DateFormat('dd/MM/yyyy HH:mm').format(
                                        widget.exitData.createdAt!.toLocal(),
                                      )
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Sección de productos ─────────────────────────
                  const Text(
                    'Productos Retirados',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_items == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: _ItemsSkeleton(),
                    )
                  else if (_items!.isEmpty)
                    const Text(
                      'No hay productos registrados.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    ...List.generate(_items!.length, (index) {
                      final item = _items![index];

                      // Construir badge adicional para lote
                      String? badgeText;
                      if (item.usesBatches) {
                        badgeText = 'Lote: ${item.batchNumber}';
                      }

                      // Etiqueta de variante + SKU combinadas
                      final variantLabel = [
                        if (item.variantAttrs != 'Única') item.variantAttrs,
                        if (item.sku != null && item.sku!.isNotEmpty)
                          'SKU: ${item.sku}',
                      ].join(' · ');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ProductItemCard(
                          imageUrl: item.imageUrl,
                          productName: item.productName,
                          variantLabel:
                              variantLabel.isNotEmpty ? variantLabel : null,
                          badgeText: badgeText,
                          badgeColor: AppColors.slate,
                          trailing: ItemPriceTrailing(
                            text: 'S/ ${item.subtotal.toStringAsFixed(2)}',
                          ),
                          progressWidget: Text(
                            '${item.quantity.toInt()} unidades × S/ ${item.unitCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          animationDelay: Duration(milliseconds: 60 * index),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton de carga
// ─────────────────────────────────────────────────────────────────────────────

class _ItemsSkeleton extends StatelessWidget {
  const _ItemsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const AppShimmer(width: 52, height: 52, borderRadius: 8),
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
              const AppShimmer(width: 60, height: 16, borderRadius: 4),
            ],
          ),
        );
      }),
    );
  }
}
