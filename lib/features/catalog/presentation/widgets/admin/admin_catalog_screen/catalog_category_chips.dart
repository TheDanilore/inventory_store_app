import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CategoryChips extends StatelessWidget {
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;
  final List<BrandEntity> brands;
  final String? selectedBrandId;
  final ValueChanged<String?>? onBrandSelected;
  final bool? filterIsActive;
  final ValueChanged<bool?>? onStatusSelected;
  final CatalogSortOption sortOption;
  final ValueChanged<CatalogSortOption> onSortSelected;
  final CatalogStockFilter stockFilter;
  final ValueChanged<CatalogStockFilter> onStockFilterSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onSelected,
    this.brands = const [],
    this.selectedBrandId,
    this.onBrandSelected,
    this.filterIsActive,
    this.onStatusSelected,
    this.sortOption = CatalogSortOption.recent,
    required this.onSortSelected,
    this.stockFilter = CatalogStockFilter.all,
    required this.onStockFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty && brands.isEmpty) return const SizedBox.shrink();

    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _SortFilterChip(
              currentSort: sortOption,
              onSelected: onSortSelected,
            ),
            const SizedBox(width: 8),
            _StockFilterChip(
              stockFilterState: stockFilter,
              onChanged: onStockFilterSelected,
            ),
            if (brands.isNotEmpty && onBrandSelected != null) ...[
              const SizedBox(width: 8),
              _BrandFilterChip(
                brands: brands,
                selectedBrandId: selectedBrandId,
                onSelected: onBrandSelected!,
              ),
            ],
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: AppColors.border),
            const SizedBox(width: 8),
            _buildChip(
              label: 'Todos',
              isSelected: selectedCategoryId == null,
              onTap: () => onSelected(null),
            ),
            const SizedBox(width: 8),
            ...categories.map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(
                  label: category.name,
                  isSelected: selectedCategoryId == category.id,
                  onTap: () => onSelected(category.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      backgroundColor: isSelected ? AppColors.primary : Colors.white,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

class _SortFilterChip extends StatelessWidget {
  final CatalogSortOption currentSort;
  final ValueChanged<CatalogSortOption> onSelected;

  const _SortFilterChip({required this.currentSort, required this.onSelected});

  Widget _buildSortItem(String label, IconData icon, bool isSelected) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_rounded : icon,
          size: 16,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CatalogSortOption>(
      tooltip: 'Ordenar por',
      onSelected: onSelected,
      itemBuilder:
          (ctx) => [
            PopupMenuItem(
              value: CatalogSortOption.recent,
              child: _buildSortItem(
                'Recientes',
                Icons.access_time_rounded,
                currentSort == CatalogSortOption.recent,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.nameAsc,
              child: _buildSortItem(
                'Nombre (A-Z)',
                Icons.sort_by_alpha_rounded,
                currentSort == CatalogSortOption.nameAsc,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.priceAsc,
              child: _buildSortItem(
                'Precio: Menor a Mayor',
                Icons.arrow_upward_rounded,
                currentSort == CatalogSortOption.priceAsc,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.priceDesc,
              child: _buildSortItem(
                'Precio: Mayor a Menor',
                Icons.arrow_downward_rounded,
                currentSort == CatalogSortOption.priceDesc,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.highStock,
              child: _buildSortItem(
                'Mayor Stock',
                Icons.inventory_2_rounded,
                currentSort == CatalogSortOption.highStock,
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sort_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              currentSort.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockFilterChip extends StatelessWidget {
  final CatalogStockFilter stockFilterState;
  final ValueChanged<CatalogStockFilter> onChanged;

  const _StockFilterChip({
    required this.stockFilterState,
    required this.onChanged,
  });

  Widget _buildSortItem(String label, IconData icon, bool isSelected) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_rounded : icon,
          size: 16,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = stockFilterState != CatalogStockFilter.all;

    return PopupMenuButton<CatalogStockFilter>(
      tooltip: 'Filtrar por Stock',
      onSelected: onChanged,
      itemBuilder:
          (ctx) => [
            PopupMenuItem(
              value: CatalogStockFilter.all,
              child: _buildSortItem(
                'Todos',
                Icons.all_inclusive_rounded,
                stockFilterState == CatalogStockFilter.all,
              ),
            ),
            PopupMenuItem(
              value: CatalogStockFilter.inStock,
              child: _buildSortItem(
                'En Stock',
                Icons.check_circle_outline_rounded,
                stockFilterState == CatalogStockFilter.inStock,
              ),
            ),
            PopupMenuItem(
              value: CatalogStockFilter.outOfStock,
              child: _buildSortItem(
                'Agotados',
                Icons.error_outline_rounded,
                stockFilterState == CatalogStockFilter.outOfStock,
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasFilter ? const Color(0xFFF0FDF4) : AppColors.background,
          border: Border.all(
            color: hasFilter ? const Color(0xFF10B981) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter
                  ? Icons.inventory_2_rounded
                  : Icons.inventory_2_outlined,
              size: 14,
              color: hasFilter ? const Color(0xFF059669) : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              'Stock: ${stockFilterState.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    hasFilter ? const Color(0xFF065F46) : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: hasFilter ? const Color(0xFF059669) : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandFilterChip extends StatelessWidget {
  final List<BrandEntity> brands;
  final String? selectedBrandId;
  final ValueChanged<String?> onSelected;

  const _BrandFilterChip({
    required this.brands,
    required this.selectedBrandId,
    required this.onSelected,
  });

  Widget _buildBrandItem(String label, bool isSelected) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_rounded : Icons.label_outline_rounded,
          size: 16,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBrand =
        brands.where((b) => b.id == selectedBrandId).firstOrNull;
    final hasFilter = selectedBrand != null;

    return PopupMenuButton<String?>(
      tooltip: 'Filtrar por Marca',
      onSelected: onSelected,
      itemBuilder:
          (ctx) => [
            PopupMenuItem<String?>(
              value: null,
              child: _buildBrandItem('Todas las marcas', selectedBrandId == null),
            ),
            ...brands.map(
              (brand) => PopupMenuItem<String?>(
                value: brand.id,
                child: _buildBrandItem(brand.name, selectedBrandId == brand.id),
              ),
            ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasFilter ? const Color(0xFFEFF6FF) : AppColors.background,
          border: Border.all(
            color: hasFilter ? const Color(0xFF3B82F6) : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.verified_rounded : Icons.verified_outlined,
              size: 14,
              color: hasFilter ? const Color(0xFF2563EB) : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              hasFilter ? 'Marca: ${selectedBrand.name}' : 'Marca: Todas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    hasFilter ? const Color(0xFF1D4ED8) : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: hasFilter ? const Color(0xFF2563EB) : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

