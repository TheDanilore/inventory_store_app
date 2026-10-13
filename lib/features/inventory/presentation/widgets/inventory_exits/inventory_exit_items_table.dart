import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';

// ── Helpers compartidos por la tabla y la tarjeta ───────────────────────────

String? _resolveImageUrl(ExitItemUI item) {
  if (item.variant.images.isNotEmpty) {
    return item.variant.images.first.imageUrl;
  }
  if (item.product.images.isNotEmpty) {
    return item.product.images
        .firstWhere(
          (img) => img.isMain,
          orElse: () => item.product.images.first,
        )
        .imageUrl;
  }
  return null;
}

String _variantText(ExitItemUI item) =>
    item.variant.attributeValues.map((v) => v.value).join(' · ');

String _batchOf(ExitItemUI item) =>
    (item.selectedBatch?['batch_number'] ?? 'DEFAULT').toString();

double _stockOf(ExitItemUI item) =>
    (item.selectedBatch?['available_quantity'] as num?)?.toDouble() ?? 0.0;

/// Solo se muestra el lote si el producto realmente se controla por lote.
bool _showBatch(ExitItemUI item) => item.product.usesBatches;

// ═════════════════════════════════════════════════════════════════════════════
// TABLA (escritorio)
// ═════════════════════════════════════════════════════════════════════════════

/// Misma estructura que la tabla de Entradas: tarjeta con título, botón tonal
/// "Agregar producto", encabezados y filas. El total vive en la barra inferior
/// fija de la pantalla.
class InventoryExitItemsTable extends StatelessWidget {
  final List<ExitItemUI> items;
  final ValueChanged<int> onRemoveItem;
  final Function(int index, double qty) onUpdateQuantity;
  final VoidCallback onAddNewRow;

  const InventoryExitItemsTable({
    super.key,
    required this.items,
    required this.onRemoveItem,
    required this.onUpdateQuantity,
    required this.onAddNewRow,
  });

  @override
  Widget build(BuildContext context) {
    final totalUnits = items.fold<double>(0.0, (s, i) => s + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(totalUnits),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            if (items.isEmpty)
              _EmptyState(onAdd: onAddNewRow)
            else ...[
              Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text('Producto', style: _headerStyle),
                    ),
                    Expanded(flex: 2, child: Text('Lote', style: _headerStyle)),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Cantidad',
                        textAlign: TextAlign.center,
                        style: _headerStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Costo unitario',
                        textAlign: TextAlign.right,
                        style: _headerStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Pérdida',
                        textAlign: TextAlign.right,
                        style: _headerStyle,
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder:
                    (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ExitRow(
                    key: ValueKey(
                      'exit_row_${item.product.id}_${item.variant.id}_${exitRowBatchKey(item)}_$index',
                    ),
                    item: item,
                    onUpdateQuantity: (qty) => onUpdateQuantity(index, qty),
                    onRemove: () => onRemoveItem(index),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double totalUnits) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Productos a retirar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'línea' : 'líneas'} · ${formatExitQty(totalUnits)} ${totalUnits == 1 ? 'unidad' : 'unidades'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (items.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: onAddNewRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar producto'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );
}

/// Clave de lote para las `ValueKey` de las filas.
String exitRowBatchKey(ExitItemUI item) =>
    (item.selectedBatch?['id'] ?? item.selectedBatch?['batch_number'] ?? '')
        .toString();

class _ExitRow extends StatelessWidget {
  final ExitItemUI item;
  final ValueChanged<double> onUpdateQuantity;
  final VoidCallback onRemove;

  const _ExitRow({
    super.key,
    required this.item,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final variantText = _variantText(item);
    final stock = _stockOf(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Producto
          Expanded(
            flex: 5,
            child: Row(
              children: [
                _Thumb(imageUrl: _resolveImageUrl(item), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (variantText.isNotEmpty)
                        Text(
                          variantText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      Text(
                        'Stock: ${formatExitQty(stock)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lote
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child:
                  _showBatch(item)
                      ? _BatchChip(label: _batchOf(item))
                      : const Text(
                        '—',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
            ),
          ),

          // Cantidad
          Expanded(
            flex: 2,
            child: Center(
              child: SizedBox(
                width: 96,
                child: ExitQuantityStepper(
                  value: item.quantity,
                  max: stock,
                  showButtons: false,
                  onChanged: onUpdateQuantity,
                ),
              ),
            ),
          ),

          // Costo unitario (solo lectura)
          Expanded(
            flex: 2,
            child: Text(
              'S/ ${item.unitCost.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Pérdida
          Expanded(
            flex: 2,
            child: Text(
              'S/ ${item.totalCost.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.danger,
              ),
            ),
          ),

          // Eliminar
          SizedBox(
            width: 48,
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppColors.danger,
                ),
                tooltip: 'Quitar',
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA (móvil)
// ═════════════════════════════════════════════════════════════════════════════

/// Línea de la salida en pantallas angostas.
class InventoryExitItemCard extends StatelessWidget {
  final ExitItemUI item;
  final ValueChanged<double> onUpdateQuantity;
  final VoidCallback onRemove;

  const InventoryExitItemCard({
    super.key,
    required this.item,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final variantText = _variantText(item);
    final stock = _stockOf(item);
    final batchMissing =
        item.product.usesBatches &&
        (_batchOf(item) == 'DEFAULT' || _batchOf(item).trim().isEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: batchMissing ? AppColors.danger : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(imageUrl: _resolveImageUrl(item), size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (variantText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          variantText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    if (item.product.usesBatches)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child:
                            batchMissing
                                ? const Text(
                                  'Falta elegir el lote',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.danger,
                                  ),
                                )
                                : _BatchChip(label: _batchOf(item)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 150,
                child: ExitQuantityStepper(
                  value: item.quantity,
                  max: stock,
                  onChanged: onUpdateQuantity,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'S/ ${item.unitCost.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'S/ ${item.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.danger,
                      ),
                    ),
                    Text(
                      'Stock: ${formatExitQty(stock)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PIEZAS
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Center(
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
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
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
      ),
    );
  }
}

class _BatchChip extends StatelessWidget {
  final String label;
  const _BatchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _Thumb({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child:
            imageUrl != null && imageUrl!.trim().isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => const Icon(
                        Icons.image_not_supported_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                )
                : Icon(
                  Icons.inventory_2_rounded,
                  size: size * 0.45,
                  color: AppColors.textMuted,
                ),
      ),
    );
  }
}
