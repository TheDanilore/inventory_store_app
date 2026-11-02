import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AttributeSelectionItem {
  String? attributeId;
  String attributeName;
  String? valueId;
  String valueName;

  AttributeSelectionItem({
    this.attributeId,
    required this.attributeName,
    this.valueId,
    required this.valueName,
  });

  Map<String, dynamic> toMap() => {
    'attribute_id': attributeId,
    'attribute_name': attributeName,
    'value_id': valueId,
    'value_name': valueName,
  };
}

class VariantCardAttributes extends StatelessWidget {
  final List<AttributeSelectionItem> attributes;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final Future<void> Function(int index) onPickKey;
  final Future<void> Function(int index) onPickValue;

  const VariantCardAttributes({
    super.key,
    required this.attributes,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onPickKey,
    required this.onPickValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Especificaciones / Atributos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            TextButton.icon(
              onPressed: onAddRow,
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Añadir propiedad',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (attributes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Sin especificaciones (Ej: Color, Talla, Material...)',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attributes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final row = attributes[idx];
              final hasKey = row.attributeName.isNotEmpty;
              final hasValue = row.valueName.isNotEmpty;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 4,
                    child: Material(
                      color: hasKey ? Colors.white : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => onPickKey(idx),
                        borderRadius: BorderRadius.circular(10),
                        hoverColor: AppColors.primary.withValues(alpha: 0.04),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  hasKey
                                      ? AppColors.primary.withValues(
                                        alpha: 0.45,
                                      )
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hasKey
                                      ? row.attributeName
                                      : 'Buscar propiedad...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        hasKey
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                    fontWeight:
                                        hasKey
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.search_rounded,
                                size: 18,
                                color:
                                    hasKey
                                        ? AppColors.primary
                                        : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Material(
                      color: hasValue ? Colors.white : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => onPickValue(idx),
                        borderRadius: BorderRadius.circular(10),
                        hoverColor: AppColors.primary.withValues(alpha: 0.04),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  hasValue
                                      ? AppColors.primary.withValues(
                                        alpha: 0.45,
                                      )
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  hasValue ? row.valueName : 'Buscar valor...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        hasValue
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                    fontWeight:
                                        hasValue
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.search_rounded,
                                size: 18,
                                color:
                                    hasValue
                                        ? AppColors.primary
                                        : Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => onRemoveRow(idx),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.shade400,
                      size: 19,
                    ),
                    tooltip: 'Eliminar propiedad',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    splashRadius: 16,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
