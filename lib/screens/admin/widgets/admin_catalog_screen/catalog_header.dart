import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

/// Barra superior del catálogo admin: buscador + toggle de búsqueda por ingrediente.
class CatalogHeader extends StatelessWidget {
  final TextEditingController searchController;
  final bool isExporting;
  final VoidCallback onExport;
  final ValueChanged<String> onSearchChanged;
  final bool searchByIngredient;
  final ValueChanged<bool> onToggleIngredientSearch;
  final VoidCallback onAddProduct;
  final bool isPosMode;

  const CatalogHeader({
    super.key,
    required this.searchController,
    required this.isExporting,
    required this.onExport,
    required this.onSearchChanged,
    required this.searchByIngredient,
    required this.onToggleIngredientSearch,
    required this.onAddProduct,
    this.isPosMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              color: Colors.white.withValues(alpha: 0.85),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 44,
                decoration: BoxDecoration(
                  color:
                      searchByIngredient
                          ? const Color(0xFFECFDF5)
                          : AppColors.background,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(
                    color:
                        searchByIngredient
                            ? const Color(0xFF10B981)
                            : AppColors.border,
                    width: searchByIngredient ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              searchByIngredient
                                  ? 'Ej: Glifosato, Clorpirifos...'
                                  : 'Buscar producto...',
                          hintStyle: TextStyle(
                            color:
                                searchByIngredient
                                    ? const Color(0xFF6EE7B7)
                                    : AppColors.textMuted,
                            fontSize: 14,
                          ),
                          prefixIcon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              searchByIngredient
                                  ? Icons.science_rounded
                                  : Icons.search_rounded,
                              key: ValueKey(searchByIngredient),
                              color:
                                  searchByIngredient
                                      ? const Color(0xFF10B981)
                                      : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Buscar por ingrediente activo',
                      child: GestureDetector(
                        onTap:
                            () => onToggleIngredientSearch(!searchByIngredient),
                        child: Container(
                          padding: const EdgeInsets.only(left: 12, right: 16),
                          color: Colors.transparent, // expande área de toque
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 32,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              color:
                                  searchByIngredient
                                      ? const Color(0xFF10B981)
                                      : AppColors.border,
                            ),
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  left: searchByIngredient ? 16 : 2,
                                  top: 2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isPosMode) ...[
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: onAddProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Crear Producto',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child:
              searchByIngredient
                  ? Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: const Color(0xFF6EE7B7),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Escribe el componente químico para ver todos los productos que lo contienen. Los filtros de categoría se desactivan en este modo.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF065F46),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 44,
                decoration: BoxDecoration(
                  color:
                      searchByIngredient
                          ? const Color(0xFFECFDF5)
                          : AppColors.background,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(
                    color:
                        searchByIngredient
                            ? const Color(0xFF10B981)
                            : AppColors.border,
                    width: searchByIngredient ? 1.5 : 1,
                  ),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        searchByIngredient
                            ? 'Ej: Glifosato, Clorpirifos...'
                            : 'Buscar producto...',
                    hintStyle: TextStyle(
                      color:
                          searchByIngredient
                              ? const Color(0xFF6EE7B7)
                              : AppColors.textMuted,
                      fontSize: 14,
                    ),
                    prefixIcon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        searchByIngredient
                            ? Icons.science_rounded
                            : Icons.search_rounded,
                        key: ValueKey(searchByIngredient),
                        color:
                            searchByIngredient
                                ? const Color(0xFF10B981)
                                : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => onToggleIngredientSearch(!searchByIngredient),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color:
                  searchByIngredient
                      ? const Color(0xFFECFDF5)
                      : AppColors.background,
              borderRadius: BorderRadius.circular(AppColors.radius),
              border: Border.all(
                color:
                    searchByIngredient
                        ? const Color(0xFF10B981)
                        : AppColors.border,
                width: searchByIngredient ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    searchByIngredient
                        ? Icons.science_rounded
                        : Icons.science_outlined,
                    key: ValueKey(searchByIngredient),
                    size: 16,
                    color:
                        searchByIngredient
                            ? const Color(0xFF059669)
                            : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        searchByIngredient
                            ? const Color(0xFF059669)
                            : AppColors.textSecondary,
                  ),
                  child: Text(
                    searchByIngredient
                        ? 'Buscando por ingrediente activo'
                        : 'Buscar por ingrediente activo',
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 34,
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color:
                        searchByIngredient
                            ? const Color(0xFF10B981)
                            : AppColors.border,
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: searchByIngredient ? 17 : 2,
                        top: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child:
              searchByIngredient
                  ? Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      border: Border.all(
                        color: const Color(0xFF6EE7B7),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Escribe el componente químico para ver todos los '
                            'productos que lo contienen. '
                            'Los filtros de categoría se desactivan en este modo.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF065F46),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
