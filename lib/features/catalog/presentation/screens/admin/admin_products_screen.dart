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
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_floating_bulk_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/desktop/products_desktop_command_bar.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/desktop/products_desktop_shimmer.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/desktop/products_desktop_table.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/mobile/products_mobile_command_bar.dart';
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
    cubit.exportCatalogPdf(
      optionsMode: 2,
      selectedIds: selected.toList(),
    );
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

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCatalogCubit>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 720;
        final isTablet = width >= 720 && width < 1100;
        final isDesktop = width >= 1100;

        return Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: BlocListener<AdminCatalogCubit, AdminCatalogState>(
            listenWhen: (previous, current) =>
                previous.actionState != current.actionState,
            listener: (context, state) {
              if (state.actionState == ViewState.error) {
                AppSnackbar.show(
                  context,
                  message: state.errorMessage ?? 'Ocurrió un error',
                  type: SnackbarType.error,
                );
              }
            },
            child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
              buildWhen: (prev, current) =>
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
                  showBackButton: true,
                  actions: [
                    if (isMobile) ...[
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        tooltip: 'Exportar PDF',
                        onPressed: () => _handleExportPdf(cubit, state),
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload_file_rounded),
                        tooltip: 'Importar Lote (CSV)',
                        onPressed: () => context.go('/products/bulk-import'),
                      ),
                    ],
                    if (!isMobile) ...[
                      OutlinedButton.icon(
                        onPressed: () => _handleExportPdf(cubit, state),
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
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
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/products/bulk-import'),
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text(
                          'Importar CSV',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => context.go('/products/product-form'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Nuevo Producto',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'N',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  floatingActionButton: isMobile
                      ? ValueListenableBuilder<bool>(
                          valueListenable: _isFabExtended,
                          builder: (context, extended, child) {
                            return extended
                                ? FloatingActionButton.extended(
                                    heroTag: 'products_add_fab',
                                    onPressed: () =>
                                        context.go('/products/product-form'),
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
                                    onPressed: () =>
                                        context.go('/products/product-form'),
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
                              // ── 1. Bento Metric Strip (Pulso en Tiempo Real) ──
                              SliverToBoxAdapter(
                                child: _buildBentoMetrics(
                                  state: state,
                                  isMobile: isMobile,
                                  isTablet: isTablet,
                                ),
                              ),

                              // ── 2. Command Bar Dinámica ────────────────────────
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    isMobile ? 16.0 : 24.0,
                                    8.0,
                                    isMobile ? 16.0 : 24.0,
                                    14.0,
                                  ),
                                  child: isMobile
                                      ? ProductsMobileCommandBar(
                                          cubit: cubit,
                                          state: state,
                                          searchCtrl: _searchCtrl,
                                          searchFocusNode: _searchFocusNode,
                                          onOpenFilters: () =>
                                              ProductsMobileFiltersSheet.show(
                                            context,
                                            cubit,
                                          ),
                                        )
                                      : ProductsDesktopCommandBar(
                                          cubit: cubit,
                                          state: state,
                                          searchCtrl: _searchCtrl,
                                          searchFocusNode: _searchFocusNode,
                                        ),
                                ),
                              ),

                              // ── 3. Contenido Principal (Data-Grid vs Tarjetas) ──
                              _buildSliverBody(
                                state,
                                cubit,
                                isDesktop: isDesktop || isTablet,
                              ),

                              // ── 4. Paginación Integrada ─────────────────────────
                              if (state.products.isNotEmpty &&
                                  state.totalPages > 1)
                                SliverToBoxAdapter(
                                  child: Container(
                                    margin: EdgeInsets.fromLTRB(
                                      isMobile ? 16.0 : 24.0,
                                      16.0,
                                      isMobile ? 16.0 : 24.0,
                                      32.0,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.border
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                    child: AdminPageBlocks(
                                      currentPage: state.currentPage,
                                      totalPages: state.totalPages,
                                      onPageChanged: cubit.setPage,
                                    ),
                                  ),
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
    final inStockCount =
        state.products.where((p) => p.totalStock > 0).length;
    final outOfStockCount =
        state.products.where((p) => p.totalStock <= 0).length;
    final totalUnits =
        state.products.fold<int>(0, (sum, p) => sum + p.totalStock);

    final cards = [
      _ProductMetricCard(
        title: 'TOTAL CATÁLOGO',
        value: '$totalCount',
        subtitle: '${state.categories.length} categorías registradas',
        icon: Icons.inventory_2_rounded,
        iconColor: AppColors.primary,
        iconBg: AppColors.primaryLight,
      ),
      _ProductMetricCard(
        title: 'EN STOCK DISPONIBLE',
        value: '$inStockCount',
        subtitle: totalCount > 0
            ? '${((inStockCount / (totalCount > 0 ? totalCount : 1)) * 100).toStringAsFixed(0)}% disponible para venta'
            : 'Listo para despacho',
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.successDark,
        iconBg: AppColors.successLight,
      ),
      _ProductMetricCard(
        title: 'AGOTADOS / CRÍTICOS',
        value: '$outOfStockCount',
        subtitle: outOfStockCount > 0
            ? 'Requieren reposición'
            : 'Sin quiebres de inventario',
        icon: Icons.warning_amber_rounded,
        iconColor: outOfStockCount > 0 ? AppColors.danger : AppColors.tealDark,
        iconBg:
            outOfStockCount > 0 ? AppColors.dangerLight : AppColors.tealLight,
        isAlert: outOfStockCount > 0,
      ),
      _ProductMetricCard(
        title: 'UNIDADES EN ALMACÉN',
        value: '$totalUnits unid.',
        subtitle: 'Existencias consolidadas',
        icon: Icons.all_inbox_rounded,
        iconColor: AppColors.info,
        iconBg: AppColors.infoLight,
      ),
    ];

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: cards[2]),
                const SizedBox(width: 8),
                Expanded(child: cards[3]),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      child: Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 10),
          Expanded(child: cards[1]),
          const SizedBox(width: 10),
          Expanded(child: cards[2]),
          const SizedBox(width: 10),
          Expanded(child: cards[3]),
        ],
      ),
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
          child: isDesktop
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
                  itemBuilder: (context, index) => const Padding(
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
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
              border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
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
                    onSelectAllPage: (selectAll) =>
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

// ── BENTO METRIC MINI CARD ──────────────────────────────────────────────────

class _ProductMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool isAlert;

  const _ProductMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: AppColors.cardShadow(opacity: 0.02),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isAlert ? AppColors.danger : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isAlert ? AppColors.danger : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
