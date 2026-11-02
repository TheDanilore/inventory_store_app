import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';

/// Contenedor estilizado para los botones de dropdown/popup de filtros en la barra de herramientas.
class ProductsDropdownContainer extends StatelessWidget {
  final bool isFiltered;
  final IconData icon;
  final String label;

  const ProductsDropdownContainer({
    super.key,
    required this.isFiltered,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:
            isFiltered
                ? AppColors.teal.withValues(alpha: 0.1)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFiltered ? AppColors.teal : const Color(0xFFE2E8F0),
          width: isFiltered ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isFiltered ? AppColors.teal : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isFiltered ? FontWeight.w800 : FontWeight.w600,
              color: isFiltered ? AppColors.tealDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: isFiltered ? AppColors.teal : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

/// Dropdown de selección de categoría para catálogo.
class ProductsCategoryDropdown extends StatelessWidget {
  final String? selectedCategoryId;
  final List<CategoryEntity> categories;
  final ValueChanged<String?> onCategoryChanged;

  const ProductsCategoryDropdown({
    super.key,
    required this.selectedCategoryId,
    required this.categories,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = selectedCategoryId != null;
    final selectedCategory =
        categories.where((c) => c.id == selectedCategoryId).firstOrNull;
    final selectedCategoryName =
        selectedCategory?.name ?? 'Todas las Categorías';

    return PopupMenuButton<String?>(
      initialValue: selectedCategoryId,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por categoría',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: onCategoryChanged,
      itemBuilder:
          (context) => [
            const PopupMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text('Todas las Categorías', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            ...categories.map(
              (c) => PopupMenuItem<String?>(
                value: c.id,
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color:
                          selectedCategoryId == c.id
                              ? AppColors.teal
                              : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selectedCategoryId == c.id
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                          color:
                              selectedCategoryId == c.id
                                  ? AppColors.tealDark
                                  : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
      child: ProductsDropdownContainer(
        isFiltered: isFiltered,
        icon: Icons.category_rounded,
        label:
            isFiltered
                ? 'Categoría: $selectedCategoryName'
                : 'Todas las Categorías',
      ),
    );
  }
}

/// Dropdown de selección de estado activo/inactivo.
class ProductsStatusDropdown extends StatelessWidget {
  final bool? filterIsActive;
  final ValueChanged<bool?> onStatusChanged;

  const ProductsStatusDropdown({
    super.key,
    required this.filterIsActive,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = filterIsActive != null;
    final statusLabel =
        filterIsActive == null
            ? 'Todos los Estados'
            : (filterIsActive! ? 'Solo Activos' : 'Solo Inactivos');

    return PopupMenuButton<bool?>(
      initialValue: filterIsActive,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por estado activo/inactivo',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: onStatusChanged,
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text('Todos los Estados', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: true,
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Solo Activos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: false,
              child: Row(
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Solo Inactivos',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
      child: ProductsDropdownContainer(
        isFiltered: isFiltered,
        icon: Icons.visibility_outlined,
        label: statusLabel,
      ),
    );
  }
}

/// Dropdown de selección de filtro por existencias (stock).
class ProductsStockDropdown extends StatelessWidget {
  final CatalogStockFilter stockFilter;
  final ValueChanged<CatalogStockFilter> onStockFilterChanged;

  const ProductsStockDropdown({
    super.key,
    required this.stockFilter,
    required this.onStockFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = stockFilter != CatalogStockFilter.all;
    String stockLabel = 'Cualquier Stock';
    if (stockFilter == CatalogStockFilter.inStock) {
      stockLabel = 'En Stock';
    } else if (stockFilter == CatalogStockFilter.outOfStock) {
      stockLabel = 'Agotados';
    }

    return PopupMenuButton<CatalogStockFilter>(
      initialValue: stockFilter,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por nivel de existencias',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: onStockFilterChanged,
      itemBuilder:
          (context) => const [
            PopupMenuItem(
              value: CatalogStockFilter.all,
              child: Row(
                children: [
                  Icon(
                    Icons.all_inbox_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text('Cualquier Stock', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem(
              value: CatalogStockFilter.inStock,
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'En Stock disponible',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: CatalogStockFilter.outOfStock,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Agotados / Críticos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
      child: ProductsDropdownContainer(
        isFiltered: isFiltered,
        icon:
            isFiltered && stockFilter == CatalogStockFilter.inStock
                ? Icons.check_circle_outline_rounded
                : (isFiltered && stockFilter == CatalogStockFilter.outOfStock
                    ? Icons.error_outline_rounded
                    : Icons.inventory_2_outlined),
        label: stockLabel,
      ),
    );
  }
}

/// Dropdown de ordenamiento del catálogo.
class ProductsSortDropdown extends StatelessWidget {
  final CatalogSortOption sortOption;
  final ValueChanged<CatalogSortOption> onSortOptionChanged;

  const ProductsSortDropdown({
    super.key,
    required this.sortOption,
    required this.onSortOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CatalogSortOption>(
      tooltip: 'Ordenar productos',
      initialValue: sortOption,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: onSortOptionChanged,
      itemBuilder:
          (context) =>
              CatalogSortOption.values.map((opt) {
                final isSelected = sortOption == opt;
                return PopupMenuItem(
                  value: opt,
                  child: Row(
                    children: [
                      if (isSelected)
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppColors.primary,
                        )
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
      child: ProductsDropdownContainer(
        isFiltered: sortOption != CatalogSortOption.recent,
        icon: Icons.sort_rounded,
        label: sortOption.label,
      ),
    );
  }
}
