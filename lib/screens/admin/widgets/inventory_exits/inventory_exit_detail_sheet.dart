import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/inventory_exit_model.dart';
import 'package:inventory_store_app/models/inventory_exit_item_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class InventoryExitDetailSheet extends StatefulWidget {
  final InventoryExitModel exitData;
  final Future<List<InventoryExitItemModel>> Function() loadItems;

  const InventoryExitDetailSheet({
    super.key,
    required this.exitData,
    required this.loadItems,
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
    if (r.contains('ROBO') || r.contains('PÉRDIDA')) return Colors.red.shade900;
    if (r.contains('CONSUMO') || r.contains('USO INTERNO')) {
      return Colors.blue.shade600;
    }
    if (r.contains('AJUSTE')) return Colors.orange.shade600;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalle de Salida',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _reasonColor(
                      widget.exitData.reason ?? '',
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 10,
                        color: _reasonColor(widget.exitData.reason ?? ''),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.exitData.reason ?? 'Sin motivo',
                        style: TextStyle(
                          fontSize: 10,
                          color: _reasonColor(widget.exitData.reason ?? ''),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.exitData.warehouseName ?? 'Desconocido',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
                              color: AppColors.textHint,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'COSTO TOTAL',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                Text(
                                  'S/ ${widget.exitData.totalCost.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.danger,
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
                                    color: AppColors.textHint,
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

                  const Text(
                    'Productos Retirados',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),

                  if (_items == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: _ItemsSkeleton(),
                    )
                  else if (_items!.isEmpty)
                    const Text(
                      'No hay productos',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    ..._items!.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
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
                                border: Border.all(color: Colors.grey.shade200),
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
                                              (context, url) => Container(
                                                color: Colors.grey.shade50,
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
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
                                                color: Colors.grey.shade50,
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 20,
                                                  color: Colors.grey.shade400,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (item.variantAttrs != 'Única')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        item.variantAttrs,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  if (item.sku != null && item.sku!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'SKU: ${item.sku}',
                                        style: const TextStyle(
                                          color: AppColors.textHint,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  if (item
                                      .usesBatches) // Solo mostrar si usa lotes
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.tag_rounded,
                                            size: 10,
                                            color: AppColors.textHint,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Lote: ${item.batchNumber}',
                                            style: const TextStyle(
                                              color: AppColors.textHint,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity.toInt()} unidades x S/ ${item.unitCost.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // ── TOTAL ───────────────────────────────────
                            Text(
                              'S/ ${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
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
              const AppShimmer(width: 60, height: 16, borderRadius: 4),
            ],
          ),
        );
      }),
    );
  }
}
