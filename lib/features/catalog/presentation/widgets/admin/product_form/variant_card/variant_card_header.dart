import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/variant_draft_form_model.dart';

class VariantCardHeader extends StatelessWidget {
  final int index;
  final VariantDraftFormModel draft;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final ValueChanged<bool> onActiveChanged;
  final TextEditingController skuCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController unitCostCtrl;
  final List<Map<String, dynamic>> attributes;

  const VariantCardHeader({
    super.key,
    required this.index,
    required this.draft,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onDuplicate,
    required this.onRemove,
    required this.onActiveChanged,
    required this.skuCtrl,
    required this.barcodeCtrl,
    required this.priceCtrl,
    required this.unitCostCtrl,
    required this.attributes,
  });

  Widget _buildImagePreview() {
    Widget? img;
    if (draft.nuevasImagenes.isNotEmpty) {
      img = Image.memory(
        draft.nuevasImagenes.first,
        fit: BoxFit.cover,
        width: 34,
        height: 34,
      );
    } else if (draft.urlsExistentes.isNotEmpty) {
      img = CachedNetworkImage(
        imageUrl: draft.urlsExistentes.first,
        fit: BoxFit.cover,
        width: 34,
        height: 34,
        placeholder: (_, _) => Container(color: Colors.grey.shade100),
        errorWidget:
            (_, _, _) =>
                const Icon(Icons.broken_image, size: 15, color: Colors.grey),
      );
    } else if (draft.externalImageUrl != null &&
        draft.externalImageUrl!.isNotEmpty) {
      img = CachedNetworkImage(
        imageUrl: draft.externalImageUrl!,
        fit: BoxFit.cover,
        width: 34,
        height: 34,
        placeholder: (_, _) => Container(color: Colors.grey.shade100),
        errorWidget:
            (_, _, _) =>
                const Icon(Icons.broken_image, size: 15, color: Colors.grey),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          img ??
          Icon(Icons.layers_outlined, size: 18, color: Colors.grey.shade400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = draft.isActive;

    return InkWell(
      onTap: onToggleExpand,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _buildImagePreview(),
            const SizedBox(width: 10),

            // Badge de número de variante
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      isActive
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.grey.shade300,
                ),
              ),
              child: Text(
                '#${index + 1}${isActive ? '' : ' (Inactiva)'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isActive ? AppColors.primary : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Resumen flexible: Atributos, SKU y Precios
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Chips de Atributos seleccionados
                  ...attributes
                      .where(
                        (a) =>
                            (a['value_name'] ?? '')
                                .toString()
                                .trim()
                                .isNotEmpty,
                      )
                      .map((attr) {
                        final attrName =
                            (attr['attribute_name'] ?? '').toString();
                        final valName = (attr['value_name'] ?? '').toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.teal.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            attrName.isNotEmpty
                                ? '$attrName: $valName'
                                : valName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      }),

                  // Chip de SKU
                  ListenableBuilder(
                    listenable: skuCtrl,
                    builder: (context, _) {
                      final sku = skuCtrl.text.trim();
                      if (sku.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'SKU: $sku',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      );
                    },
                  ),

                  // Chip de Código de Barras
                  ListenableBuilder(
                    listenable: barcodeCtrl,
                    builder: (context, _) {
                      final bc = barcodeCtrl.text.trim();
                      if (bc.isEmpty) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.barcode_reader,
                              size: 11,
                              color: Colors.blueGrey.shade700,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              bc,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Precio de venta y Margen
                  ListenableBuilder(
                    listenable: Listenable.merge([priceCtrl, unitCostCtrl]),
                    builder: (context, _) {
                      final priceText = priceCtrl.text.trim();
                      if (priceText.isEmpty) return const SizedBox.shrink();
                      final p = double.tryParse(priceText) ?? 0.0;
                      final c =
                          double.tryParse(unitCostCtrl.text.trim()) ?? 0.0;
                      final hasCost = c > 0 && p > 0;
                      final margin = hasCost ? ((p - c) / p) * 100 : 0.0;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'S/ ${p.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (hasCost) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    margin >= 25
                                        ? AppColors.success.withValues(
                                          alpha: 0.12,
                                        )
                                        : margin > 0
                                        ? AppColors.warning.withValues(
                                          alpha: 0.12,
                                        )
                                        : AppColors.error.withValues(
                                          alpha: 0.12,
                                        ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      margin >= 25
                                          ? AppColors.success
                                          : margin > 0
                                          ? AppColors.warning
                                          : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Switch Activa / Inactiva
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: isActive,
                onChanged: onActiveChanged,
                activeThumbColor: AppColors.success,
              ),
            ),

            // Menú contextual
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.grey,
                size: 20,
              ),
              tooltip: 'Opciones de variante',
              onSelected: (value) {
                if (value == 'duplicate') onDuplicate();
                if (value == 'delete') onRemove();
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text('Duplicar variante'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Eliminar variante',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
            ),

            // Chevron indicador de despliegue con rotación suave
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
