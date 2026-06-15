import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart'; // For EntryItemUI
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

  @override
  Widget build(BuildContext context) {
    String? currentImageUrl;
    if (item.variant.images.isNotEmpty) {
      currentImageUrl = item.variant.images.first.imageUrl;
    } else if (item.product.images.isNotEmpty) {
      currentImageUrl = item.product.images.firstWhere((img) => img.isMain, orElse: () => item.product.images.first).imageUrl;
    }

    final String variantAttrs = item.variant.label.replaceAll(item.product.name, '').trim();
    final String attributesText = variantAttrs.isNotEmpty ? variantAttrs : 'Variante Única';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen miniatura
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: currentImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: currentImageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    memCacheWidth: 120,
                    placeholder: (_, _) => AppShimmer(width: 60, height: 60, borderRadius: 10),
                    errorWidget: (_, _, _) => _ImagePlaceholder(),
                  )
                : _ImagePlaceholder(),
          ),
          const SizedBox(width: 12),
          // Info Central
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (attributesText.isNotEmpty && attributesText != 'Variante Única')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      attributesText,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 6),
                if (item.product.usesBatches)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Lote: ${item.batchNumber}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          // Bloque derecho (Cantidad, Precio, Eliminar)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onEditQuantity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'x${item.quantity.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 12, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'S/ ${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                ),
              )
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
    child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textHint, size: 24),
  );
}
