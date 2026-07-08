import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CatalogDialogs {
  static Future<({int mode, Set<String> selectedIds})?> showExportOptionsDialog(
    BuildContext context,
    List<ProductEntity> max50Products,
    int visibleCount,
  ) {
    return showDialog<({int mode, Set<String> selectedIds})>(
      context: context,
      builder: (context) {
        int selectedMode = 1;
        final selectedIds = <String>{};

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusXl),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm,
                            ),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Exportar catálogo a PDF',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _ExportRadioOption(
                      title: 'Solo esta página',
                      subtitle: '$visibleCount productos visibles',
                      value: 0,
                      groupValue: selectedMode,
                      onChanged:
                          (v) => setLocalState(() => selectedMode = v as int),
                    ),
                    const SizedBox(height: 8),

                    _ExportRadioOption(
                      title: 'Todos los productos',
                      subtitle: 'Máximo 50 productos (recomendado)',
                      value: 1,
                      groupValue: selectedMode,
                      onChanged:
                          (v) => setLocalState(() => selectedMode = v as int),
                    ),
                    const SizedBox(height: 8),

                    _ExportRadioOption(
                      title: 'Selección personalizada',
                      subtitle: 'Elige los productos a incluir',
                      value: 2,
                      groupValue: selectedMode,
                      onChanged:
                          (v) => setLocalState(() => selectedMode = v as int),
                    ),

                    if (selectedMode == 2) ...[
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppColors.radius),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: max50Products.length,
                          itemBuilder: (context, index) {
                            final product = max50Products[index];
                            final productId = product.id;
                            final isSelected = selectedIds.contains(productId);
                            return CheckboxListTile(
                              dense: true,
                              value: isSelected,
                              activeColor: AppColors.teal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusSm,
                                ),
                              ),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                'Stock: ${product.totalStock > 0 ? product.totalStock : "Sin stock"} · ${product.isActive ? "Activo" : "Inactivo"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              onChanged: (checked) {
                                setLocalState(() {
                                  if (checked == true) {
                                    selectedIds.add(productId);
                                  } else {
                                    selectedIds.remove(productId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                selectedMode == 2 && selectedIds.isEmpty
                                    ? null
                                    : () => Navigator.pop(context, (
                                      mode: selectedMode,
                                      selectedIds: selectedIds,
                                    )),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Generar PDF',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<bool?> showToggleProductActiveDialog(
    BuildContext context,
    ProductEntity product,
  ) {
    final willActivate = !product.isActive;
    return showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusXl),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          willActivate
                              ? AppColors.successLight
                              : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      willActivate
                          ? Icons.check_circle_rounded
                          : Icons.hide_source_rounded,
                      color:
                          willActivate ? AppColors.success : AppColors.danger,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    willActivate ? 'Activar producto' : 'Desactivar producto',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    willActivate
                        ? '¿Volver a mostrar "${product.name}" en el catálogo?'
                        : '¿Ocultar "${product.name}" del catálogo?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                willActivate
                                    ? AppColors.success
                                    : AppColors.danger,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radius,
                              ),
                            ),
                          ),
                          child: Text(
                            willActivate ? 'Sí, activar' : 'Sí, desactivar',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _ExportRadioOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final int groupValue;
  final ValueChanged<int?> onChanged;

  const _ExportRadioOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppColors.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight.withValues(alpha: 0.3) : null,
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppColors.radius),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: groupValue,
              // ignore: deprecated_member_use
              onChanged: onChanged,
              activeColor: AppColors.teal,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
