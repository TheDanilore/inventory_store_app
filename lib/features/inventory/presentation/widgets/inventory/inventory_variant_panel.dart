import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batch_detail_pane.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_palette.dart';

/// Panel de detalle de una variante (patrón master-detail de Stock).
///
/// Misma idea que el panel derecho de la pestaña Lotes: seleccionas una fila
/// y ves a la derecha cuánto hay, qué lotes la componen y cuál vence primero,
/// sin salir de la lista. Muestra primero lo urgente (FEFO).
class InventoryVariantPanel extends StatelessWidget {
  final InventoryStockItem item;
  final String warehouseName;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;
  final VoidCallback onKardex;
  final VoidCallback? onViewLots;

  const InventoryVariantPanel({
    super.key,
    required this.item,
    required this.warehouseName,
    required this.onClose,
    required this.onOpenDetail,
    required this.onKardex,
    this.onViewLots,
  });

  static DateTime? _parse(String? s) => s == null ? null : DateTime.tryParse(s);

  @override
  Widget build(BuildContext context) {
    final p = InventoryPalette.of(context);

    final lots =
        item.batches.where((b) => b.availableQuantity > 0).toList()..sort((a, b) {
          final da = _parse(a.expiryDate), db = _parse(b.expiryDate);
          if (da == null && db == null) return 0;
          if (da == null) return 1; // sin vencimiento al final
          if (db == null) return -1;
          return da.compareTo(db);
        });

    final Color stockColor =
        item.stock <= 0
            ? AppColors.danger
            : (item.isLowStock ? AppColors.warning : AppColors.success);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(left: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Cabecera ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child:
                        (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                            ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              memCacheWidth: 120,
                              memCacheHeight: 120,
                              fit: BoxFit.cover,
                              errorWidget:
                                  (c, u, e) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 18,
                                    color: p.textMuted,
                                  ),
                            )
                            : Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                              color: p.textMuted,
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.attrsText} · ${item.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar (Esc)',
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, size: 20, color: p.textSecondary),
                ),
              ],
            ),
          ),

          // ── Cifras clave ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Kpi(label: 'En stock', value: '${item.stock}', color: stockColor),
                const SizedBox(width: 8),
                _Kpi(
                  label: 'Reorden',
                  value: item.stockControl ? '${item.reorderPoint}' : '—',
                ),
                const SizedBox(width: 8),
                _Kpi(label: 'Lotes', value: item.usesBatches ? '${lots.length}' : '—'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              warehouseName,
              style: TextStyle(fontSize: 11.5, color: p.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: p.border),

          // ── Lotes, primero lo que vence antes ──
          Expanded(
            child:
                !item.usesBatches
                    ? _Note(
                      icon: Icons.layers_clear_outlined,
                      text: 'Este producto no se controla por lotes.',
                    )
                    : lots.isEmpty
                    ? _Note(
                      icon: Icons.inventory_2_outlined,
                      text: 'No hay lotes con stock disponible.',
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: lots.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _LotRow(batch: lots[i]),
                    ),
          ),

          // ── Acciones ──
          Divider(height: 1, color: p.border),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Ficha completa'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: onKardex, child: const Text('Kardex')),
                if (onViewLots != null && item.usesBatches) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Ver estos lotes en la pestaña Lotes',
                    onPressed: onViewLots,
                    icon: const Icon(Icons.event_busy_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Kpi({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final p = InventoryPalette.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: color ?? p.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Note({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final p = InventoryPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: p.border),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LotRow extends StatelessWidget {
  final InventoryBatchItem batch;
  const _LotRow({required this.batch});

  @override
  Widget build(BuildContext context) {
    final p = InventoryPalette.of(context);
    final d = InventoryVariantPanel._parse(batch.expiryDate);

    Color color = AppColors.success;
    String label = 'Sin vencimiento';
    if (d != null) {
      final days = d.difference(DateTime.now()).inDays;
      if (days < 0) {
        color = AppColors.danger;
        label = 'Vencido';
      } else if (days <= 14) {
        color = AppColors.danger;
        label = days == 0 ? 'Vence hoy' : 'Vence en $days d';
      } else if (days <= 30) {
        color = AppColors.warning;
        label = 'Vence en $days d';
      } else {
        label =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
    }

    return Material(
      color: p.background,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => InventoryBatchDetailPane.showAsBottomSheet(context, batch),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.batchNumber,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${batch.availableQuantity} uds.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: p.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
