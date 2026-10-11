import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';

/// Barra de comandos de escritorio estilo Stripe / Linear para catálogo de productos.
/// Integra búsqueda avanzada, atajos de teclado sin badges visuales, filtros unificados
/// con el diseño de órdenes de compra, y reubicación de acciones masivas y creación.
class ProductsDesktopCommandBar extends StatelessWidget {
  final AdminCatalogCubit cubit;
  final AdminCatalogState state;
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final VoidCallback onNewProduct;
  final VoidCallback onExportPdf;
  final VoidCallback onBulkImport;

  const ProductsDesktopCommandBar({
    super.key,
    required this.cubit,
    required this.state,
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.onNewProduct,
    required this.onExportPdf,
    required this.onBulkImport,
  });

  int _countActiveFilters() {
    int count = 0;
    if (state.stockFilter != CatalogStockFilter.all) count++;
    if (state.selectedCategoryId != null) count++;
    if (state.selectedBrandId != null) count++;
    if (state.filterIsActive != null) count++;
    if (state.searchByIngredient) count++;
    return count;
  }

  String _getStockLabel(CatalogStockFilter filter) {
    switch (filter) {
      case CatalogStockFilter.all:
        return 'Todos';
      case CatalogStockFilter.inStock:
        return 'En Stock';
      case CatalogStockFilter.outOfStock:
        return 'Agotados';
    }
  }

  String _getStatusLabel(bool? filterIsActive) {
    if (filterIsActive == null) return 'Todos';
    return filterIsActive ? 'Activos' : 'Inactivos';
  }

  Widget _buildDropdownContainer({
    required bool isFiltered,
    required IconData icon,
    required String label,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 11),
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

  Widget _buildStockDropdown(BuildContext context) {
    final isFiltered = state.stockFilter != CatalogStockFilter.all;

    return PopupMenuButton<CatalogStockFilter>(
      initialValue: state.stockFilter,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por nivel de existencias',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: cubit.setStockFilter,
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: CatalogStockFilter.all,
              child: Row(
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Todos los niveles de stock',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
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
            const PopupMenuItem(
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
      child: _buildDropdownContainer(
        isFiltered: isFiltered,
        icon:
            isFiltered && state.stockFilter == CatalogStockFilter.inStock
                ? Icons.check_circle_outline_rounded
                : (isFiltered &&
                        state.stockFilter == CatalogStockFilter.outOfStock
                    ? Icons.error_outline_rounded
                    : Icons.inventory_2_outlined),
        label: 'Stock: ${_getStockLabel(state.stockFilter)}',
      ),
    );
  }

  Widget _buildCategoryDropdown(
    BuildContext context,
    String selectedCategoryName,
  ) {
    final isFiltered = state.selectedCategoryId != null;

    return PopupMenuButton<String?>(
      initialValue: state.selectedCategoryId,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por categoría',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: cubit.setCategory,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String?>>[
          PopupMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                if (!isFiltered)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.primary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                const Text(
                  'Todas las categorías',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ];

        for (final cat in state.categories) {
          final isCatSelected = state.selectedCategoryId == cat.id;
          items.add(
            PopupMenuItem<String?>(
              value: cat.id,
              child: Row(
                children: [
                  if (isCatSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isCatSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return items;
      },
      child: _buildDropdownContainer(
        isFiltered: isFiltered,
        icon: Icons.folder_outlined,
        label: 'Categoría: $selectedCategoryName',
      ),
    );
  }

  Widget _buildBrandDropdown(BuildContext context, String selectedBrandName) {
    final isFiltered = state.selectedBrandId != null;

    return PopupMenuButton<String?>(
      initialValue: state.selectedBrandId,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por marca',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: cubit.setBrand,
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String?>>[
          PopupMenuItem<String?>(
            value: null,
            child: Row(
              children: [
                if (!isFiltered)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.primary,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                const Text(
                  'Todas las marcas',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ];

        for (final brand in state.brands) {
          final isBrandSelected = state.selectedBrandId == brand.id;
          items.add(
            PopupMenuItem<String?>(
              value: brand.id,
              child: Row(
                children: [
                  if (isBrandSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    brand.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isBrandSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return items;
      },
      child: _buildDropdownContainer(
        isFiltered: isFiltered,
        icon: Icons.verified_outlined,
        label: 'Marca: $selectedBrandName',
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context) {
    final isFiltered = state.filterIsActive != null;

    return PopupMenuButton<bool?>(
      initialValue: state.filterIsActive,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por estado activo/inactivo',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: cubit.setFilterIsActive,
      itemBuilder:
          (context) => [
            const PopupMenuItem(
              value: null,
              child: Row(
                children: [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Text('Todos los estados', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
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
            const PopupMenuItem(
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
      child: _buildDropdownContainer(
        isFiltered: isFiltered,
        icon: Icons.visibility_outlined,
        label: 'Estado: ${_getStatusLabel(state.filterIsActive)}',
      ),
    );
  }

  Widget _buildIngredientToggle() {
    final isSelected = state.searchByIngredient;

    return Tooltip(
      message:
          'Conmutar para buscar por componente, fórmula o principio activo',
      child: InkWell(
        onTap: () => cubit.toggleSearchByIngredient(!isSelected),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.accentLight.withValues(alpha: 0.2)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.accent.withValues(alpha: 0.7)
                      : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.science_rounded : Icons.science_outlined,
                size: 15,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Principio Activo',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color:
                      isSelected ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    return PopupMenuButton<CatalogSortOption>(
      tooltip: 'Ordenar productos',
      initialValue: state.sortOption,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: cubit.setSortOption,
      itemBuilder:
          (context) =>
              CatalogSortOption.values.map((opt) {
                final isSelected = state.sortOption == opt;
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
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sort_rounded,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Ordenar: ${state.sortOption.label}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFiltersCount = _countActiveFilters();
    final hasActiveFilters = activeFiltersCount > 0;

    final selectedCategory = state.categories.firstWhereOrNull(
      (c) => c.id == state.selectedCategoryId,
    );
    final selectedCategoryName = selectedCategory?.name ?? 'Todas';

    final selectedBrand = state.brands.firstWhereOrNull(
      (b) => b.id == state.selectedBrandId,
    );
    final selectedBrandName = selectedBrand?.name ?? 'Todas';

    return AdminProToolbar(
      isDesktop: true,
      searchController: searchCtrl,
      searchFocusNode: searchFocusNode,
      searchHint:
          state.searchByIngredient
              ? 'Buscar por principio activo / fórmula farmacéutica...'
              : 'Buscar por nombre, código o SKU...',
      onSearchChanged: cubit.setSearchTerm,
      onClearSearch: () {
        searchCtrl.clear();
        cubit.clearSearch();
      },
      onSearchSubmitted: (val) => cubit.submitSearch(val),
      searchKeyHint: '/',
      searchFlex: 5,
      onRefresh: () => cubit.refreshProducts(),
      refreshTooltip: 'Recargar catálogo (Atajo: R)',
      trailingActions: [
        // Exportar PDF
        Tooltip(
          message: 'Exportar catálogo en PDF',
          child: SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: onExportPdf,
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              label: const Text(
                'Exportar PDF',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                backgroundColor: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),

        // Importar CSV
        Tooltip(
          message: 'Importar lote de productos desde CSV',
          child: SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: onBulkImport,
              icon: const Icon(
                Icons.upload_file_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              label: const Text(
                'Importar CSV',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                backgroundColor: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
      ],
      primaryAction: AdminProToolbarAction(
        label: 'Nuevo Producto',
        icon: Icons.add_rounded,
        onPressed: onNewProduct,
        keyHint: 'N',
      ),
      secondaryRow: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 1. Dropdown Filtro de Stock (Estilo Órdenes de Compra)
            _buildStockDropdown(context),
            const SizedBox(width: 8),

            // 2. Dropdown Filtro de Categoría
            _buildCategoryDropdown(context, selectedCategoryName),
            const SizedBox(width: 8),

            // 3. Dropdown Filtro de Marca (si existen marcas registradas)
            if (state.brands.isNotEmpty) ...[
              _buildBrandDropdown(context, selectedBrandName),
              const SizedBox(width: 8),
            ],

            // 4. Dropdown Filtro de Estado (Activo / Inactivo)
            _buildStatusDropdown(context),
            const SizedBox(width: 8),

            // 5. Conmutador de Búsqueda por Principio Activo
            _buildIngredientToggle(),
            const SizedBox(width: 8),

            // 6. Selector de Ordenamiento
            _buildSortDropdown(context),

            // 7. Botón Limpiar Filtros
            if (hasActiveFilters) ...[
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: () {
                  cubit.setCategory(null);
                  cubit.setBrand(null);
                  cubit.setStockFilter(CatalogStockFilter.all);
                  cubit.setFilterIsActive(null);
                  if (state.searchByIngredient) {
                    cubit.toggleSearchByIngredient(false);
                  }
                },
                icon: const Icon(
                  Icons.clear_all_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                label: const Text(
                  'Limpiar filtros',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

          ],
        ),
      ),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
    );
  }
}
