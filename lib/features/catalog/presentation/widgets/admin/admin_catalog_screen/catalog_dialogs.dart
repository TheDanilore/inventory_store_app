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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        int selectedMode = 1;
        final selectedIds = <String>{};

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : Colors.transparent,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFDC2626).withValues(alpha: 0.5)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exportar Catálogo a PDF',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Configura los productos a incluir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                            ),
                            onPressed: () => Navigator.pop(context),
                            tooltip: 'Cerrar',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _ExportRadioOption(
                        title: 'Solo esta página',
                        subtitle:
                            '$visibleCount productos visibles en pantalla',
                        value: 0,
                        groupValue: selectedMode,
                        onChanged:
                            (v) => setLocalState(() => selectedMode = v as int),
                      ),
                      const SizedBox(height: 10),

                      _ExportRadioOption(
                        title: 'Todos los productos',
                        subtitle: 'Máximo 50 productos en formato catálogo',
                        value: 1,
                        groupValue: selectedMode,
                        onChanged:
                            (v) => setLocalState(() => selectedMode = v as int),
                      ),
                      const SizedBox(height: 10),

                      _ExportRadioOption(
                        title: 'Selección personalizada',
                        subtitle:
                            'Elige manualmente entre los ${max50Products.length} productos cargados',
                        value: 2,
                        groupValue: selectedMode,
                        onChanged:
                            (v) => setLocalState(() => selectedMode = v as int),
                      ),

                      if (selectedMode == 2) ...[
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 240),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: max50Products.length,
                            itemBuilder: (context, index) {
                              final product = max50Products[index];
                              final productId = product.id;
                              final isSelected = selectedIds.contains(
                                productId,
                              );
                              return CheckboxListTile(
                                dense: true,
                                value: isSelected,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                title: Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  'Stock: ${product.totalStock > 0 ? product.totalStock : "Sin stock"} · ${product.isActive ? "Activo" : "Inactivo"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
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
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                                backgroundColor: isDark ? AppColors.primary : const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Generar PDF',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusXl),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : Colors.transparent,
              ),
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
                              ? (isDark
                                  ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                                  : AppColors.successLight)
                              : (isDark
                                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
                                  : AppColors.dangerLight),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      willActivate
                          ? Icons.check_circle_rounded
                          : Icons.hide_source_rounded,
                      color:
                          willActivate
                              ? (isDark ? const Color(0xFF34D399) : AppColors.success)
                              : (isDark ? const Color(0xFFF87171) : AppColors.danger),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    willActivate ? 'Activar producto' : 'Desactivar producto',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    willActivate
                        ? '¿Volver a mostrar "${product.name}" en el catálogo?'
                        : '¿Ocultar "${product.name}" del catálogo?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                              side: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.border,
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppColors.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                  : AppColors.tealLight.withValues(alpha: 0.3))
              : (isDark ? AppColors.darkSurfaceElevated : null),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF34D399) : AppColors.teal)
                : (isDark ? AppColors.darkBorder : AppColors.border),
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
              activeColor: isDark ? const Color(0xFF34D399) : AppColors.teal,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
