import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_filter_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_searchable_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. CHIP ADAPTATIVO DE CATEGORÍA (ESCALA A CUALQUIER CANTIDAD)
// ─────────────────────────────────────────────────────────────────────────────
class CategoryFilterChip extends StatelessWidget {
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const CategoryFilterChip({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  void _openPicker(BuildContext context) {
    AppFeedbackService.selectionClick();
    // Conversión diferida O(N): solo se genera la lista al abrir el modal,
    // ahorrando tiempo de CPU y memoria RAM en cada reconstrucción de pantalla.
    final items = List<FilterPickerItem>.generate(
      categories.length,
      (index) => (id: categories[index].id, name: categories[index].name),
      growable: false,
    );

    CatalogSearchableItemPicker.show(
      context: context,
      title: 'Categoría',
      allLabel: 'Todas las categorías',
      defaultIcon: Icons.category_rounded,
      items: items,
      selectedId: selectedCategoryId,
      onSelected: onSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    CategoryEntity? selectedCategory;
    if (selectedCategoryId != null) {
      for (final c in categories) {
        if (c.id == selectedCategoryId) {
          selectedCategory = c;
          break;
        }
      }
    }
    final isSelected = selectedCategory != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                        : AppColors.primaryLight)
                    : (isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.surface),
            border: Border.all(
              color:
                  isSelected
                      ? (isDark ? const Color(0xFF3B82F6) : AppColors.primary)
                      : (isDark ? AppColors.darkBorder : AppColors.border),
              width: isSelected ? 1.2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.category_rounded : Icons.category_outlined,
                size: 15,
                color:
                    isSelected
                        ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                isSelected
                    ? 'Categoría: ${selectedCategory.name}'
                    : 'Categoría: Todas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected
                          ? (isDark
                              ? const Color(0xFF93C5FD)
                              : AppColors.primary)
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              if (isSelected)
                GestureDetector(
                  onTap: () {
                    AppFeedbackService.lightImpact();
                    onSelected(null);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                              : AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color:
                          isDark ? const Color(0xFF93C5FD) : AppColors.primary,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. CHIP ADAPTATIVO DE MARCA (ESCALA A CUALQUIER CANTIDAD)
// ─────────────────────────────────────────────────────────────────────────────
class BrandFilterChip extends StatelessWidget {
  final List<BrandEntity> brands;
  final String? selectedBrandId;
  final ValueChanged<String?> onSelected;

  const BrandFilterChip({
    super.key,
    required this.brands,
    required this.selectedBrandId,
    required this.onSelected,
  });

  void _openPicker(BuildContext context) {
    AppFeedbackService.selectionClick();
    final items = List<FilterPickerItem>.generate(
      brands.length,
      (index) => (id: brands[index].id, name: brands[index].name),
      growable: false,
    );

    CatalogSearchableItemPicker.show(
      context: context,
      title: 'Marca',
      allLabel: 'Todas las marcas',
      defaultIcon: Icons.verified_rounded,
      items: items,
      selectedId: selectedBrandId,
      onSelected: onSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    BrandEntity? selectedBrand;
    if (selectedBrandId != null) {
      for (final b in brands) {
        if (b.id == selectedBrandId) {
          selectedBrand = b;
          break;
        }
      }
    }
    final isSelected = selectedBrand != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (isDark
                        ? AppColors.info.withValues(alpha: 0.2)
                        : AppColors.infoLight)
                    : (isDark
                        ? AppColors.darkSurfaceElevated
                        : AppColors.surface),
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.info
                      : (isDark ? AppColors.darkBorder : AppColors.border),
              width: isSelected ? 1.2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.verified_rounded : Icons.verified_outlined,
                size: 15,
                color:
                    isSelected
                        ? AppColors.info
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                isSelected ? 'Marca: ${selectedBrand.name}' : 'Marca: Todas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected
                          ? (isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0369A1))
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 6),
              if (isSelected)
                GestureDetector(
                  onTap: () {
                    AppFeedbackService.lightImpact();
                    onSelected(null);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(
                        alpha: isDark ? 0.3 : 0.18,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 13,
                      color:
                          isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0369A1),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
