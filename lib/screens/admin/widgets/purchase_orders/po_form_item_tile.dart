import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/entry_item_ui.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class POFormItemTile extends StatelessWidget {
  final EntryItemUI item;
  final VoidCallback onEditQuantity;
  final VoidCallback onRemove;

  const POFormItemTile({
    super.key,
    required this.item,
    required this.onEditQuantity,
    required this.onRemove,
  });

  /// Retorna el color semafórico del chip de lote según la fecha de vencimiento.
  /// 🔴 < 30 días | 🟡 30–90 días | 🟢 > 90 días o sin vencimiento
  Color _batchChipColor() {
    if (item.expiryDate == null) return AppColors.success;
    final daysLeft = item.expiryDate!.difference(DateTime.now()).inDays;
    if (daysLeft < 30) return AppColors.danger;
    if (daysLeft < 90) return const Color(0xFFF59E0B); // amber
    return AppColors.success;
  }

  /// Muestra un diálogo de confirmación antes de eliminar el ítem.
  Future<void> _confirmRemove(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Quitar producto',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Text(
              '¿Eliminar "${item.product.name}" de la orden?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
    if (confirm == true) onRemove();
  }

  @override
  Widget build(BuildContext context) {
    String? currentImageUrl;
    if (item.variant.images.isNotEmpty) {
      currentImageUrl = item.variant.images.first.imageUrl;
    } else if (item.product.images.isNotEmpty) {
      currentImageUrl =
          item.product.images
              .firstWhere(
                (img) => img.isMain,
                orElse: () => item.product.images.first,
              )
              .imageUrl;
    }

    final String variantAttrs =
        item.variant.label.replaceAll(item.product.name, '').trim();
    final String attributesText =
        variantAttrs.isNotEmpty ? variantAttrs : 'Variante Única';

    // Mostrar cantidad con o sin decimal según sea entero o no
    final String quantityText =
        item.quantity % 1 == 0
            ? 'x${item.quantity.toInt()}'
            : 'x${item.quantity.toStringAsFixed(2)}';

    final Color batchColor = _batchChipColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen miniatura
          Semantics(
            label: 'Imagen de ${item.product.name}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  currentImageUrl != null
                      ? CachedNetworkImage(
                        imageUrl: currentImageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        placeholder:
                            (_, _) => AppShimmer(
                              width: 60,
                              height: 60,
                              borderRadius: 10,
                            ),
                        errorWidget: (_, _, _) => _ImagePlaceholder(),
                      )
                      : _ImagePlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          // Info Central
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attributesText.isNotEmpty &&
                    attributesText != 'Variante Única')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      attributesText,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                // Chip de lote con color semafórico
                if (item.product.usesBatches &&
                    item.batchNumber.isNotEmpty &&
                    item.batchNumber != 'DEFAULT')
                  Semantics(
                    label:
                        'Lote ${item.batchNumber}${item.expiryDate != null ? ', vence el ${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}' : ''}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: batchColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: batchColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Lote: ${item.batchNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          color: batchColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Bloque derecho (Cantidad, Precio, Eliminar)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Botón editar cantidad con ripple y semántica
              Semantics(
                label: 'Editar cantidad, actualmente $quantityText',
                button: true,
                child: InkWell(
                  onTap: onEditQuantity,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          quantityText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'S/ ${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Botón eliminar con confirmación y semántica
              Semantics(
                label: 'Eliminar ${item.product.name} de la orden',
                button: true,
                child: Tooltip(
                  message: 'Quitar de la orden',
                  child: InkWell(
                    onTap: () => _confirmRemove(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.danger,
                      ),
                    ),
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

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(
      Icons.image_not_supported_outlined,
      color: AppColors.textHint,
      size: 24,
    ),
  );
}
