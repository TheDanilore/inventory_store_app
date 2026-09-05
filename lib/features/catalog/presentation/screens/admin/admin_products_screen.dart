import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
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

// Intents para atajos de teclado Pro Tool (Linear / Stripe style)
class SearchIntent extends Intent {
  const SearchIntent();
}

class NewProductIntent extends Intent {
  const NewProductIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

/// Pantalla Principal de Catálogo de Productos para Administradores.
/// Diseño camaleónico de alta densidad para Desktop y estilo Apple HIG para Móvil.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  // Selección múltiple para acciones por lote estilo Pro Tool
  final Set<String> _selectedProductIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 15 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 15 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchCtrl.text = context.read<AdminCatalogCubit>().state.searchTerm;
    });
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Text(
                  'Eliminar Producto',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: Text(
              '¿Estás seguro de que deseas eliminar "${product.name}"?\n\nEsta acción no se puede deshacer y fallará si el producto tiene stock en almacenes o ventas asociadas.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final success = await cubit.deleteProduct(product.id);
      if (success && mounted) {
        setState(() {
          _selectedProductIds.remove(product.id);
        });
        AppSnackbar.show(
          context,
          message: 'Producto eliminado correctamente',
          type: SnackbarType.success,
        );
      }
    }
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
    if (_selectedProductIds.isEmpty) return;
    cubit.exportCatalogPdf(
      optionsMode: 2,
      selectedIds: _selectedProductIds.toList(),
    );
  }

  void _showProductQuickView(ProductEntity product, AdminCatalogCubit cubit) {
    ProductQuickViewSheet.show(
      context,
      product: product,
      cubit: cubit,
      onToggleActive: () => _toggleProductoActivo(product, cubit),
      onEdit: () {
        Navigator.pop(context);
        context.go(
          '/admin/products/product-form/${product.id}',
          extra: {'productToEdit': product},
        );
      },
      onOpenFullDetail: () {
        Navigator.pop(context);
        context.go('/admin/product/${product.id}', extra: product);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCatalogCubit>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const SearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const NewProductIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const NewProductIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (SearchIntent intent) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          NewProductIntent: CallbackAction<NewProductIntent>(
            onInvoke: (NewProductIntent intent) {
              context.go('/admin/products/product-form');
              return null;
            },
          ),
          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (EscapeIntent intent) {
              if (_selectedProductIds.isNotEmpty) {
                setState(() => _selectedProductIds.clear());
              } else {
                _searchFocusNode.unfocus();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: BlocListener<AdminCatalogCubit, AdminCatalogState>(
            listenWhen:
                (previous, current) =>
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
              builder: (context, state) {
                return AdminLayout(
                  title: 'Inventario de Productos',
                  showBackButton: true,
                  actions: [
                    if (!isDesktop) ...[
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        tooltip: 'Exportar PDF',
                        onPressed: () => _handleExportPdf(cubit, state),
                      ),
                      IconButton(
                        icon: const Icon(Icons.upload_file_rounded),
                        tooltip: 'Importar Lote (CSV)',
                        onPressed:
                            () => context.go('/admin/products/bulk-import'),
                      ),
                    ],
                    if (isDesktop) ...[
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed:
                            () => context.go('/admin/products/bulk-import'),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed:
                            () => context.go('/admin/products/product-form'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppColors.radiusSm,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Nuevo Producto',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                  floatingActionButton:
                      !isDesktop
                          ? ValueListenableBuilder<bool>(
                            valueListenable: _isFabExtended,
                            builder: (context, extended, child) {
                              return extended
                                  ? FloatingActionButton.extended(
                                    onPressed:
                                        () => context.go(
                                          '/admin/products/product-form',
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
                                    onPressed:
                                        () => context.go(
                                          '/admin/products/product-form',
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
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktopLayout = constraints.maxWidth >= 900;

                      return Stack(
                        children: [
                          Container(
                            color: AppColors.background,
                            padding: EdgeInsets.all(
                              isDesktopLayout ? 24.0 : 16.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Command Bar ─────────────────────────────────────────
                                if (isDesktopLayout)
                                  ProductsDesktopCommandBar(
                                    cubit: cubit,
                                    state: state,
                                    searchCtrl: _searchCtrl,
                                    searchFocusNode: _searchFocusNode,
                                  )
                                else
                                  ProductsMobileCommandBar(
                                    cubit: cubit,
                                    state: state,
                                    searchCtrl: _searchCtrl,
                                    searchFocusNode: _searchFocusNode,
                                    onOpenFilters:
                                        () => ProductsMobileFiltersSheet.show(
                                          context,
                                          cubit,
                                        ),
                                  ),

                                const SizedBox(height: 16),

                                // ── Contenido Principal (Data-Grid vs Tarjetas) ─────────
                                Expanded(
                                  child: _buildBodyContent(
                                    state,
                                    cubit,
                                    isDesktop: isDesktopLayout,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Floating Bulk Action Bar ───────────────────────────
                          if (_selectedProductIds.isNotEmpty)
                            ProductsFloatingBulkBar(
                              selectedCount: _selectedProductIds.length,
                              isDesktop: isDesktopLayout,
                              onExportPdf: () => _handleBulkExportPdf(cubit),
                              onClearSelection:
                                  () => setState(
                                    () => _selectedProductIds.clear(),
                                  ),
                            ),

                          // ── Overlay de carga de acciones ───────────────────────
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
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(
    AdminCatalogState state,
    AdminCatalogCubit cubit, {
    required bool isDesktop,
  }) {
    if (state.catalogState == ViewState.loading ||
        state.catalogState == ViewState.initial) {
      return isDesktop
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
            itemCount: 6,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder:
                (context, index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppShimmer(
                    width: double.infinity,
                    height: 104,
                    borderRadius: 16,
                  ),
                ),
          );
    }

    if (state.errorMessage != null && state.products.isEmpty) {
      return Center(
        child: CatalogErrorState(
          message: state.errorMessage!,
          onRetry: () => cubit.refreshProducts(),
        ),
      );
    }

    if (state.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
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
                  setState(() => _selectedProductIds.clear());
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
      );
    }

    Widget contentList;
    if (isDesktop) {
      contentList = Container(
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
          child: ProductsDesktopTable(
            products: state.products,
            selectedProductIds: _selectedProductIds,
            matchedIngredients: state.matchedIngredients,
            onProductSelected: (id, isSelected) {
              setState(() {
                if (isSelected) {
                  _selectedProductIds.add(id);
                } else {
                  _selectedProductIds.remove(id);
                }
              });
            },
            onSelectAllPage: (selectAll) {
              setState(() {
                if (selectAll) {
                  for (final p in state.products) {
                    _selectedProductIds.add(p.id);
                  }
                } else {
                  for (final p in state.products) {
                    _selectedProductIds.remove(p.id);
                  }
                }
              });
            },
            onRowTap: (p) => _showProductQuickView(p, cubit),
            onToggleActive: (p) => _toggleProductoActivo(p, cubit),
            onEdit: (p) {
              context.go(
                '/admin/products/product-form/${p.id}',
                extra: {'productToEdit': p},
              );
            },
            onDelete: (p) => _confirmDeleteProduct(p, cubit),
          ),
        ),
      );
    } else {
      contentList = ProductsMobileCardList(
        products: state.products,
        matchedIngredients: state.matchedIngredients,
        scrollController: _scrollController,
        onTapProduct: (p) => _showProductQuickView(p, cubit),
        onToggleActive: (p) => _toggleProductoActivo(p, cubit),
        onEdit: (p) {
          context.go(
            '/admin/products/product-form/${p.id}',
            extra: {'productToEdit': p},
          );
        },
        onDelete: (p) => _confirmDeleteProduct(p, cubit),
        onOpenFullDetail: (p) {
          context.go('/admin/product/${p.id}', extra: p);
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: () async => cubit.refreshProducts(),
            child: contentList,
          ),
        ),
        if (state.products.isNotEmpty && state.totalPages > 1)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: AdminPageBlocks(
                currentPage: state.currentPage,
                totalPages: state.totalPages,
                onPageChanged: cubit.setPage,
              ),
            ),
          ),
      ],
    );
  }
}
