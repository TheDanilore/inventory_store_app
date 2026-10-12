import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/dialogs/adaptive_destructive_dialog.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/core/widgets/admin_page_header.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_floating_bulk_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/desktop/products_desktop_shimmer.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/desktop/products_desktop_table.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/mobile/products_mobile_filters_sheet.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/mobile/products_mobile_card_list.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/quick_view/product_quick_view_sheet.dart';

/// Pantalla Principal de Catálogo e Inventario de Productos para Administradores.
/// Diseño camaleónico de alta densidad para Desktop, eficiencia híbrida para Tablet
/// y ergonomía estilo Apple HIG para Móvil.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final FocusNode _screenFocusNode;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);
  bool _isTableView = true;

  // Selección múltiple aislada mediante ValueNotifier (previene re-renders globales)
  final ValueNotifier<Set<String>> _selectedProductIdsNotifier =
      ValueNotifier<Set<String>>({});

  @override
  void initState() {
    super.initState();
    _screenFocusNode = FocusNode();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        _searchCtrl.text = context.read<AdminCatalogCubit>().state.searchTerm;
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      if (_scrollController.offset > 20 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 20 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    _selectedProductIdsNotifier.dispose();
    super.dispose();
  }

  // ── REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ────────────────────
  bool get _isInputFieldFocused =>
      FocusUtils.isInputFieldFocused(_searchFocusNode);

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo editable, aislar atajos globales
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Atajo [/] -> Enfocar buscador con selección total
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nuevo Producto
    if (key == LogicalKeyboardKey.keyN) {
      context.go('/products/product-form');
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar catálogo
    if (key == LogicalKeyboardKey.keyR) {
      context.read<AdminCatalogCubit>().refreshProducts();
      AppSnackbar.show(
        context,
        message: 'Catálogo de productos actualizado',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla Pro vs Tarjetas)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajo [Escape] -> Limpiar búsqueda o selección
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedProductIdsNotifier.value.isNotEmpty) {
        _clearSelection();
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        context.read<AdminCatalogCubit>().setSearchTerm('');
        return KeyEventResult.handled;
      }
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _toggleProductSelected(String id, bool isSelected) {
    final current = Set<String>.from(_selectedProductIdsNotifier.value);
    if (isSelected) {
      current.add(id);
    } else {
      current.remove(id);
    }
    _selectedProductIdsNotifier.value = current;
  }

  void _selectAllPage(List<ProductEntity> pageProducts, bool selectAll) {
    final current = Set<String>.from(_selectedProductIdsNotifier.value);
    if (selectAll) {
      for (final p in pageProducts) {
        current.add(p.id);
      }
    } else {
      for (final p in pageProducts) {
        current.remove(p.id);
      }
    }
    _selectedProductIdsNotifier.value = current;
  }

  void _clearSelection() {
    if (_selectedProductIdsNotifier.value.isNotEmpty) {
      _selectedProductIdsNotifier.value = {};
    }
  }

  Future<void> _toggleProductoActivo(
    ProductEntity product,
    AdminCatalogCubit cubit,
  ) async {
    await cubit.toggleProductActive(product);
  }

  Future<void> _confirmDeleteProduct(
    ProductEntity product,
    AdminCatalogCubit cubit,
  ) async {
    final variantCount = product.productVariants.length;
    final variantText =
        variantCount > 0 ? ' y sus $variantCount variantes vinculadas' : '';

    await AdaptiveDestructiveDialog.show(
      context: context,
      title: 'Eliminar Producto',
      itemName: product.name,
      matchText: product.name,
      description:
          'Esta acción eliminará permanentemente "${product.name}"$variantText, sus códigos de barra, relaciones de inventario y configuración de precios.\n\nNota de Seguridad: La acción será rechazada si el producto cuenta con existencias activas en almacén, órdenes de compra a proveedores, ventas o movimientos en Kardex.',
      confirmButtonText: 'Eliminar Producto',
      onConfirmAsync: () async {
        final success = await cubit.deleteProduct(product.id);
        if (success && mounted) {
          _toggleProductSelected(product.id, false);
          AppSnackbar.show(
            context,
            message: 'Producto eliminado correctamente',
            type: SnackbarType.success,
          );
        }
        return success;
      },
    );
  }

  Future<void> _handleExportPdf(
    AdminCatalogCubit cubit,
    AdminCatalogState state,
  ) async {
    final res = await CatalogDialogs.showExportOptionsDialog(
      context,
      state.products,
      state.products.length,
    );
    if (res != null && mounted) {
      await cubit.exportCatalogPdf(
        optionsMode: res.mode,
        selectedIds: res.selectedIds.toList(),
      );
    }
  }

  void _handleBulkExportPdf(AdminCatalogCubit cubit) {
    final selected = _selectedProductIdsNotifier.value;
    if (selected.isEmpty) return;
    cubit.exportCatalogPdf(optionsMode: 2, selectedIds: selected.toList());
  }

  void _showProductQuickView(ProductEntity product, AdminCatalogCubit cubit) {
    ProductQuickViewSheet.show(
      context,
      product: product,
      cubit: cubit,
      onToggleActive: () => _toggleProductoActivo(product, cubit),
      onEdit: () {
        context.go(
          '/products/product-form/${product.id}',
          extra: {'productToEdit': product},
        );
      },
      onOpenFullDetail: () {
        context.go('/product/${product.id}', extra: product);
      },
    );
  }

  int _countActiveFilters(AdminCatalogState state) {
    int count = 0;
    if (state.stockFilter != CatalogStockFilter.all) count++;
    if (state.selectedCategoryId != null) count++;
    if (state.selectedBrandId != null) count++;
    if (state.filterIsActive != null) count++;
    if (state.searchByIngredient) count++;
    return count;
  }

  Widget _buildDropdownContainer({
    required bool isFiltered,
    required IconData icon,
    required String label,
  }) {
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

  Widget _buildCategoryDropdown(
    BuildContext context,
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
    final isFiltered = state.selectedCategoryId != null;
    final selectedCategory =
        state.categories
            .where((c) => c.id == state.selectedCategoryId)
            .firstOrNull;
    final selectedCategoryName =
        selectedCategory?.name ?? 'Todas las Categorías';

    return PopupMenuButton<String?>(
      initialValue: state.selectedCategoryId,
      offset: const Offset(0, 44),
      tooltip: 'Filtrar por categoría',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: cubit.setCategory,
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
            ...state.categories.map(
              (c) => PopupMenuItem<String?>(
                value: c.id,
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color:
                          state.selectedCategoryId == c.id
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
                              state.selectedCategoryId == c.id
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                          color:
                              state.selectedCategoryId == c.id
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
      child: _buildDropdownContainer(
        isFiltered: isFiltered,
        icon: Icons.category_rounded,
        label:
            isFiltered
                ? 'Categoría: $selectedCategoryName'
                : 'Todas las Categorías',
      ),
    );
  }

  Widget _buildStatusDropdown(
    BuildContext context,
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
    final isFiltered = state.filterIsActive != null;
    final statusLabel =
        state.filterIsActive == null
            ? 'Todos los Estados'
            : (state.filterIsActive! ? 'Solo Activos' : 'Solo Inactivos');

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
      child: _buildDropdownContainer(
        isFiltered: isFiltered,
        icon: Icons.visibility_outlined,
        label: statusLabel,
      ),
    );
  }

  Widget _buildStockDropdown(
    BuildContext context,
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
    final isFiltered = state.stockFilter != CatalogStockFilter.all;
    String stockLabel = 'Cualquier Stock';
    if (state.stockFilter == CatalogStockFilter.inStock) {
      stockLabel = 'En Stock';
    } else if (state.stockFilter == CatalogStockFilter.outOfStock) {
      stockLabel = 'Agotados';
    }

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
      child: _buildDropdownContainer(
        isFiltered: isFiltered,
        icon:
            isFiltered && state.stockFilter == CatalogStockFilter.inStock
                ? Icons.check_circle_outline_rounded
                : (isFiltered &&
                        state.stockFilter == CatalogStockFilter.outOfStock
                    ? Icons.error_outline_rounded
                    : Icons.inventory_2_outlined),
        label: stockLabel,
      ),
    );
  }

  Widget _buildSortDropdown(
    BuildContext context,
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
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
      child: _buildDropdownContainer(
        isFiltered: state.sortOption != CatalogSortOption.recent,
        icon: Icons.sort_rounded,
        label: state.sortOption.label,
      ),
    );
  }

  Widget _buildPaginationSliver(
    AdminCatalogState state,
    AdminCatalogCubit cubit,
    BuildContext context,
    bool isMobile,
  ) {
    if (state.products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 24));
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16.0 : 24.0,
          16.0,
          isMobile ? 16.0 : 24.0,
          32.0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.03),
          ),
          child: AdminPageBlocks(
            currentPage: state.currentPage,
            totalPages: state.totalPages,
            onPageChanged: cubit.setPage,
            totalItems: state.totalCount,
            itemsPerPage: state.itemsPerPage,
            onItemsPerPageChanged: cubit.setItemsPerPage,
            itemName: 'productos',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCatalogCubit>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 720;
        final isTablet = width >= 720 && width < 1100;

        return Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: BlocListener<AdminCatalogCubit, AdminCatalogState>(
            listenWhen:
                (previous, current) =>
                    previous.actionState != current.actionState ||
                    previous.currentPage != current.currentPage ||
                    previous.searchTerm != current.searchTerm ||
                    previous.selectedCategoryId != current.selectedCategoryId ||
                    previous.selectedBrandId != current.selectedBrandId ||
                    previous.stockFilter != current.stockFilter,
            listener: (context, state) {
              if (state.actionState == ViewState.error) {
                AppSnackbar.show(
                  context,
                  message: state.errorMessage ?? 'Ocurrió un error',
                  type: SnackbarType.error,
                );
              }
              // Limpiar selecciones huérfanas al navegar entre páginas o cambiar filtros
              if (_selectedProductIdsNotifier.value.isNotEmpty) {
                _selectedProductIdsNotifier.value = {};
              }
            },
            child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
              buildWhen:
                  (prev, current) =>
                      prev.catalogState != current.catalogState ||
                      prev.products != current.products ||
                      prev.currentPage != current.currentPage ||
                      prev.totalPages != current.totalPages ||
                      prev.totalCount != current.totalCount ||
                      prev.actionState != current.actionState ||
                      prev.selectedCategoryId != current.selectedCategoryId ||
                      prev.selectedBrandId != current.selectedBrandId ||
                      prev.filterIsActive != current.filterIsActive ||
                      prev.stockFilter != current.stockFilter ||
                      prev.sortOption != current.sortOption ||
                      prev.searchTerm != current.searchTerm ||
                      prev.searchByIngredient != current.searchByIngredient,
              builder: (context, state) {
                return AdminLayout(
                  title: 'Inventario de Productos',
                  actions:
                      isMobile
                          ? [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              tooltip: 'Exportar PDF',
                              onPressed: () => _handleExportPdf(cubit, state),
                            ),
                            IconButton(
                              icon: const Icon(Icons.upload_file_rounded),
                              tooltip: 'Importar Lote (CSV)',
                              onPressed:
                                  () => context.go('/products/bulk-import'),
                            ),
                          ]
                          : null,
                  floatingActionButton:
                      isMobile
                          ? ValueListenableBuilder<bool>(
                            valueListenable: _isFabExtended,
                            builder: (context, extended, child) {
                              return extended
                                  ? FloatingActionButton.extended(
                                    heroTag: 'products_add_fab',
                                    onPressed:
                                        () => context.go(
                                          '/products/product-form',
                                        ),
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text(
                                      'Nuevo Producto',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                  : FloatingActionButton(
                                    heroTag: 'products_add_fab',
                                    onPressed:
                                        () => context.go(
                                          '/products/product-form',
                                        ),
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    tooltip: 'Nuevo Producto',
                                    child: const Icon(Icons.add_rounded),
                                  );
                            },
                          )
                          : null,
                  body: Stack(
                    children: [
                      Container(
                        color: AppColors.background,
                        child: RefreshIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          onRefresh: () async => cubit.refreshProducts(),
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              // ── 0. Cabecera Ejecutiva Stripe / Linear (Arriba de Métricas) ──
                              SliverToBoxAdapter(
                                child: AdminPageHeader(
                                  title: 'Catálogo de Productos',
                                  subtitle:
                                      'Administra precios, márgenes brutos, inventario en tiempo real y visibilidad multicanal.',
                                  isDesktop: !isMobile,
                                  actions: [
                                    AdminHeaderButton.outlined(
                                      label: 'Importar',
                                      icon: Icons.upload_file_rounded,
                                      tooltip:
                                          'Importar lote de productos desde CSV',
                                      onPressed:
                                          () => context.go(
                                            '/products/bulk-import',
                                          ),
                                    ),
                                    AdminHeaderButton.outlined(
                                      label: 'Exportar CSV',
                                      icon: Icons.table_chart_outlined,
                                      iconColor: const Color(0xFF10B981),
                                      tooltip: 'Exportar catálogo en PDF / CSV',
                                      onPressed:
                                          () => _handleExportPdf(cubit, state),
                                    ),
                                    AdminHeaderButton.primary(
                                      label: 'Nuevo Producto',
                                      icon: Icons.add_rounded,
                                      tooltip:
                                          'Registrar nuevo producto (Atajo: N)',
                                      onPressed:
                                          () => context.go(
                                            '/products/product-form',
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── 1. Bento Metric Strip (Pulso en Tiempo Real) ──
                              SliverToBoxAdapter(
                                child: _buildBentoMetrics(
                                  state: state,
                                  isMobile: isMobile,
                                  isTablet: isTablet,
                                ),
                              ),

                              // ── 2. Toolbar Pro Unificado (Fila Única Desktop & 44dp Mobile) ──
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    isMobile ? 16.0 : 24.0,
                                    8.0,
                                    isMobile ? 16.0 : 24.0,
                                    14.0,
                                  ),
                                  child: AdminProToolbar(
                                    isDesktop: !isMobile,
                                    searchController: _searchCtrl,
                                    searchFocusNode: _searchFocusNode,
                                    searchHint:
                                        state.searchByIngredient
                                            ? 'Buscar por principio activo / fórmula farmacéutica...'
                                            : 'Buscar por título, SKU, código de barras o etiqueta...',
                                    onSearchChanged: cubit.setSearchTerm,
                                    onClearSearch: () {
                                      _searchCtrl.clear();
                                      cubit.clearSearch();
                                    },
                                    onSearchSubmitted:
                                        (val) => cubit.submitSearch(val),
                                    searchKeyHint: '/',
                                    filterWidgets: [
                                      _buildCategoryDropdown(
                                        context,
                                        state,
                                        cubit,
                                      ),
                                      _buildStatusDropdown(
                                        context,
                                        state,
                                        cubit,
                                      ),
                                      _buildStockDropdown(
                                        context,
                                        state,
                                        cubit,
                                      ),
                                      _buildSortDropdown(context, state, cubit),
                                    ],
                                    viewToggleConfig: AdminProViewToggleConfig(
                                      isTableView: _isTableView,
                                      onToggleTableView:
                                          (val) => setState(
                                            () => _isTableView = val,
                                          ),
                                    ),
                                    onRefresh: () => cubit.refreshProducts(),
                                    refreshTooltip:
                                        'Recargar catálogo (Atajo: R)',
                                    onOpenMobileFilters:
                                        () => ProductsMobileFiltersSheet.show(
                                          context,
                                          cubit,
                                        ),
                                    activeFiltersCount: _countActiveFilters(
                                      state,
                                    ),
                                  ),
                                ),
                              ),

                              // ── 3. Contenido Principal (Data-Grid vs Tarjetas) ──
                              _buildSliverBody(
                                state,
                                cubit,
                                isDesktop: !isMobile && _isTableView,
                              ),

                              // ── 4. Paginación Integrada (AdminPageBlocks) ──
                              _buildPaginationSliver(
                                state,
                                cubit,
                                context,
                                isMobile,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Floating Bulk Action Bar ───────────────────────────────
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: _selectedProductIdsNotifier,
                        builder: (context, selectedIds, _) {
                          if (selectedIds.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return ProductsFloatingBulkBar(
                            selectedCount: selectedIds.length,
                            isDesktop: !isMobile,
                            onExportPdf: () => _handleBulkExportPdf(cubit),
                            onClearSelection: _clearSelection,
                          );
                        },
                      ),

                      // ── Overlay de carga de acciones ───────────────────────────
                      if (state.actionState == ViewState.loading)
                        Positioned.fill(
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.45),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ── BENTO METRICS HEADER ────────────────────────────────────────────────────

  Widget _buildBentoMetrics({
    required AdminCatalogState state,
    required bool isMobile,
    required bool isTablet,
  }) {
    final totalCount = state.totalCount;
    final inStockCount = state.products.where((p) => p.totalStock > 0).length;
    final outOfStockCount =
        state.products.where((p) => p.totalStock <= 0).length;
    final totalUnits = state.products.fold<int>(
      0,
      (sum, p) => sum + p.totalStock,
    );
    final isMultiPage = state.totalPages > 1;

    return AdminKpiMetricsBar(
      isDesktop: !isMobile,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 12 : 14,
        isMobile ? 16 : 24,
        4,
      ),
      isMobileGrid: true,
      items: [
        AdminKpiItem(
          title: 'TOTAL CATÁLOGO',
          value: '$totalCount',
          subtitle: '${state.categories.length} categorías registradas',
          icon: Icons.inventory_2_rounded,
          accentColor: AppColors.primary,
          gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
          iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
          borderColor: const Color(0xFFE2E8F0),
          glowColor: const Color(0x1F0F172A),
        ),
        AdminKpiItem(
          title: isMultiPage ? 'EN STOCK (PÁG)' : 'EN STOCK DISPONIBLE',
          value: '$inStockCount',
          subtitle:
              isMultiPage
                  ? '$inStockCount en pág. actual'
                  : (totalCount > 0
                      ? '${((inStockCount / (totalCount > 0 ? totalCount : 1)) * 100).toStringAsFixed(0)}% disponible para venta'
                      : 'Listo para despacho'),
          icon: Icons.check_circle_outline_rounded,
          accentColor: AppColors.successDark,
          gradientColors: const [Colors.white, Color(0xFFECFDF5)],
          iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor: const Color(0xFFA7F3D0),
          glowColor: const Color(0x2E10B981),
        ),
        AdminKpiItem(
          title: isMultiPage ? 'AGOTADOS (PÁG)' : 'AGOTADOS / CRÍTICOS',
          value: '$outOfStockCount',
          subtitle:
              isMultiPage
                  ? '$outOfStockCount en pág. actual'
                  : (outOfStockCount > 0
                      ? 'Requieren reposición'
                      : 'Sin quiebres de inventario'),
          icon: Icons.warning_amber_rounded,
          accentColor:
              outOfStockCount > 0 ? AppColors.danger : AppColors.tealDark,
          gradientColors: [
            Colors.white,
            outOfStockCount > 0
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFF0FDFA),
          ],
          iconGradient:
              outOfStockCount > 0
                  ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                  : const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor:
              outOfStockCount > 0
                  ? const Color(0xFFFECACA)
                  : const Color(0xFF99F6E4),
          glowColor:
              outOfStockCount > 0
                  ? const Color(0x2EEF4444)
                  : const Color(0x2E0D9488),
          isAlert: outOfStockCount > 0,
        ),
        AdminKpiItem(
          title: 'UNIDADES EN ALMACÉN',
          value: '$totalUnits unid.',
          subtitle: isMultiPage ? 'En pág. actual' : 'Existencias consolidadas',
          icon: Icons.all_inbox_rounded,
          accentColor: AppColors.info,
          gradientColors: const [Colors.white, Color(0xFFF0F9FF)],
          iconGradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
          borderColor: const Color(0xFFBAE6FD),
          glowColor: const Color(0x2E0EA5E9),
        ),
      ],
    );
  }

  // ── CONTENIDO PRINCIPAL SLIVER ──────────────────────────────────────────────

  Widget _buildSliverBody(
    AdminCatalogState state,
    AdminCatalogCubit cubit, {
    required bool isDesktop,
  }) {
    if (state.catalogState == ViewState.loading ||
        state.catalogState == ViewState.initial) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0),
        sliver: SliverToBoxAdapter(
          child:
              isDesktop
                  ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppColors.radiusLg),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                    ),
                    child: const ProductsDesktopShimmer(rows: 6),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    itemBuilder:
                        (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: AppShimmer(
                            width: double.infinity,
                            height: 104,
                            borderRadius: 16,
                          ),
                        ),
                  ),
        ),
      );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Center(
            child: CatalogErrorState(
              message: state.errorMessage!,
              onRetry: () => cubit.refreshProducts(),
            ),
          ),
        ),
      );
    }

    if (state.products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No se encontraron productos',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Prueba ajustando el término de búsqueda o cambiando los filtros seleccionados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    _clearSelection();
                    cubit.setSearchTerm('');
                    cubit.setCategory(null);
                    cubit.setStockFilter(CatalogStockFilter.all);
                    cubit.setFilterIsActive(null);
                    if (state.searchByIngredient) {
                      cubit.toggleSearchByIngredient(false);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Restablecer Filtros'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isDesktop) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        sliver: SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              child: ValueListenableBuilder<Set<String>>(
                valueListenable: _selectedProductIdsNotifier,
                builder: (context, selectedIds, _) {
                  return ProductsDesktopTable(
                    products: state.products,
                    selectedProductIds: selectedIds,
                    matchedIngredients: state.matchedIngredients,
                    onProductSelected: _toggleProductSelected,
                    onSelectAllPage:
                        (selectAll) =>
                            _selectAllPage(state.products, selectAll),
                    onRowTap: (p) => _showProductQuickView(p, cubit),
                    onToggleActive: (p) => _toggleProductoActivo(p, cubit),
                    onEdit: (p) {
                      context.go(
                        '/products/product-form/${p.id}',
                        extra: {'productToEdit': p},
                      );
                    },
                    onDelete: (p) => _confirmDeleteProduct(p, cubit),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverToBoxAdapter(
        child: ProductsMobileCardList(
          products: state.products,
          matchedIngredients: state.matchedIngredients,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onTapProduct: (p) => _showProductQuickView(p, cubit),
          onToggleActive: (p) => _toggleProductoActivo(p, cubit),
          onEdit: (p) {
            context.go(
              '/products/product-form/${p.id}',
              extra: {'productToEdit': p},
            );
          },
          onDelete: (p) => _confirmDeleteProduct(p, cubit),
          onOpenFullDetail: (p) {
            context.go('/product/${p.id}', extra: p);
          },
        ),
      ),
    );
  }
}
