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
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';

class SearchIntent extends Intent {
  const SearchIntent();
}

class NewProductIntent extends Intent {
  const NewProductIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

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

  // ── Quick View Slide-Over (Desktop) & BottomSheet (Mobile) ────────────────
  void _showProductQuickView(ProductEntity product, AdminCatalogCubit cubit) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (isDesktop) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'QuickView',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(-8, 0),
                    ),
                  ],
                ),
                child: _ProductQuickViewContent(
                  product: product,
                  cubit: cubit,
                  isSideSheet: true,
                  onToggleActive: () => _toggleProductoActivo(product, cubit),
                  onEdit: () {
                    Navigator.pop(dialogContext);
                    context.go(
                      '/admin/products/product-form/${product.id}',
                      extra: {'productToEdit': product},
                    );
                  },
                  onOpenFullDetail: () {
                    Navigator.pop(dialogContext);
                    context.go('/admin/product/${product.id}', extra: product);
                  },
                ),
              ),
            ),
          );
        },
        transitionBuilder: (context, anim, secondaryAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: _ProductQuickViewContent(
              product: product,
              cubit: cubit,
              isSideSheet: false,
              onToggleActive: () => _toggleProductoActivo(product, cubit),
              onEdit: () {
                Navigator.pop(ctx);
                context.go(
                  '/admin/products/product-form/${product.id}',
                  extra: {'productToEdit': product},
                );
              },
              onOpenFullDetail: () {
                Navigator.pop(ctx);
                context.go('/admin/product/${product.id}', extra: product);
              },
            ),
          );
        },
      );
    }
  }

  String _getMonogram(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'PR';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.length >= 2
        ? clean.substring(0, 2).toUpperCase()
        : clean[0].toUpperCase();
  }

  int _countActiveFilters(AdminCatalogState state) {
    int count = 0;
    if (state.stockFilter != CatalogStockFilter.all) count++;
    if (state.selectedCategoryId != null) count++;
    if (state.filterIsActive != null) count++;
    if (state.searchByIngredient) count++;
    return count;
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
              } else if (state.actionState == ViewState.success) {
                // Éxito individual manejado localmente
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
                                // ── Command Bar & Filtros Pro ─────────────────────────
                                if (isDesktopLayout)
                                  _buildDesktopCommandBar(cubit, state)
                                else
                                  _buildMobileCommandBar(cubit, state),

                                const SizedBox(height: 16),

                                // ── Contenido Camaleónico (Desktop vs Mobile) ──────────
                                Expanded(
                                  child:
                                      isDesktopLayout
                                          ? _buildDesktopTableContainer(
                                            state,
                                            cubit,
                                          )
                                          : _buildMobileCardList(state, cubit),
                                ),
                              ],
                            ),
                          ),

                          // ── Floating Bulk Action Bar (Linear / Stripe style) ───
                          if (_selectedProductIds.isNotEmpty)
                            _buildFloatingBulkActionBar(cubit, isDesktopLayout),

                          // ── Overlay de carga de acciones ──────────────────────
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

  // ── Desktop Command Bar (Stripe / Linear) ──────────────────────────────────
  Widget _buildDesktopCommandBar(
    AdminCatalogCubit cubit,
    AdminCatalogState state,
  ) {
    final activeFiltersCount = _countActiveFilters(state);
    final hasActiveFilters = activeFiltersCount > 0;

    String? selectedCategoryName;
    if (state.selectedCategoryId != null) {
      try {
        selectedCategoryName =
            state.categories
                .firstWhere((c) => c.id == state.selectedCategoryId)
                .name;
      } catch (_) {
        selectedCategoryName = 'Categoría';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 4),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nivel 1: Buscador + Principio Activo + Ordenamiento + Actualizar
          Row(
            children: [
              // Buscador compacto Pro
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    onChanged: cubit.setSearchTerm,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          state.searchByIngredient
                              ? 'Buscar por principio activo / fórmula farmacéutica...'
                              : 'Buscar por nombre, código o SKU...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                cubit.setSearchTerm('');
                              },
                              tooltip: 'Limpiar búsqueda',
                            ),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.slateLight.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Ctrl+K',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Chip Conmutador de Búsqueda por Principio Activo
              Tooltip(
                message:
                    'Conmutar para buscar por componente, fórmula o principio activo',
                child: FilterChip(
                  selected: state.searchByIngredient,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 15,
                        color:
                            state.searchByIngredient
                                ? AppColors.accent
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Principio Activo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              state.searchByIngredient
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  selectedColor: AppColors.accentLight.withValues(alpha: 0.2),
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                    color:
                        state.searchByIngredient
                            ? AppColors.accent.withValues(alpha: 0.6)
                            : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  onSelected: (val) => cubit.toggleSearchByIngredient(val),
                ),
              ),
              const SizedBox(width: 10),

              // Selector de Ordenamiento
              PopupMenuButton<CatalogSortOption>(
                tooltip: 'Ordenar productos',
                initialValue: state.sortOption,
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
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sort_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.sortOption.label,
                        style: const TextStyle(
                          fontSize: 12,
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
              ),
              const SizedBox(width: 10),

              // Botón Actualizar
              OutlinedButton.icon(
                onPressed: () => cubit.refreshProducts(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Actualizar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  backgroundColor: AppColors.background,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Nivel 2: Filtros Segmentados de Stock + Categorías + Estado + Limpiar
          Row(
            children: [
              // Chips Segmentados de Stock
              _buildSegmentChip(
                label: 'Todos',
                isSelected: state.stockFilter == CatalogStockFilter.all,
                onTap: () => cubit.setStockFilter(CatalogStockFilter.all),
              ),
              const SizedBox(width: 6),
              _buildSegmentChip(
                label: 'En Stock',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.success,
                isSelected: state.stockFilter == CatalogStockFilter.inStock,
                onTap: () => cubit.setStockFilter(CatalogStockFilter.inStock),
              ),
              const SizedBox(width: 6),
              _buildSegmentChip(
                label: 'Agotados',
                icon: Icons.error_outline_rounded,
                iconColor: AppColors.danger,
                isSelected: state.stockFilter == CatalogStockFilter.outOfStock,
                onTap:
                    () => cubit.setStockFilter(CatalogStockFilter.outOfStock),
              ),

              const SizedBox(width: 14),
              Container(width: 1, height: 20, color: AppColors.border),
              const SizedBox(width: 14),

              // Filtro Dropdown de Categoría
              PopupMenuButton<String?>(
                tooltip: 'Filtrar por categoría',
                onSelected: cubit.setCategory,
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String?>>[
                    PopupMenuItem<String?>(
                      value: null,
                      child: Row(
                        children: [
                          if (state.selectedCategoryId == null)
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
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
                                    isCatSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return items;
                },
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color:
                        state.selectedCategoryId != null
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color:
                          state.selectedCategoryId != null
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 14,
                        color:
                            state.selectedCategoryId != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedCategoryName ?? 'Categoría',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              state.selectedCategoryId != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color:
                            state.selectedCategoryId != null
                                ? AppColors.primary
                                : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Filtro Dropdown de Estado (Activo / Inactivo)
              PopupMenuButton<bool?>(
                tooltip: 'Filtrar por estado',
                onSelected: cubit.setFilterIsActive,
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: null,
                        child: Row(
                          children: [
                            if (state.filterIsActive == null)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Todos los estados',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: Row(
                          children: [
                            if (state.filterIsActive == true)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Solo Activos',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: false,
                        child: Row(
                          children: [
                            if (state.filterIsActive == false)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Solo Inactivos',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color:
                        state.filterIsActive != null
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color:
                          state.filterIsActive != null
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color:
                            state.filterIsActive != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.filterIsActive == null
                            ? 'Estado'
                            : (state.filterIsActive! ? 'Activos' : 'Inactivos'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              state.filterIsActive != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color:
                            state.filterIsActive != null
                                ? AppColors.primary
                                : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              if (hasActiveFilters) ...[
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () {
                    cubit.setCategory(null);
                    cubit.setStockFilter(CatalogStockFilter.all);
                    cubit.setFilterIsActive(null);
                    if (state.searchByIngredient) {
                      cubit.toggleSearchByIngredient(false);
                    }
                  },
                  icon: const Icon(
                    Icons.clear_all_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  label: const Text(
                    'Limpiar filtros',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Contador de productos
              Text(
                '${state.totalCount} ${state.totalCount == 1 ? "producto" : "productos"}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Mobile Command Bar (Apple HIG) ─────────────────────────────────────────
  Widget _buildMobileCommandBar(
    AdminCatalogCubit cubit,
    AdminCatalogState state,
  ) {
    final activeFiltersCount = _countActiveFilters(state);
    final hasActiveFilters = activeFiltersCount > 0;

    return Row(
      children: [
        // Buscador expandible
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radius),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              onChanged: cubit.setSearchTerm,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText:
                    state.searchByIngredient
                        ? 'Buscar por componente...'
                        : 'Buscar producto o código...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            cubit.setSearchTerm('');
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Botón de Filtros con Badge semántico (Abre BottomSheet Apple)
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    hasActiveFilters
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(
                  color: hasActiveFilters ? AppColors.primary : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => _showMobileFiltersBottomSheet(cubit, state),
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color:
                      hasActiveFilters
                          ? AppColors.primary
                          : AppColors.textSecondary,
                ),
                tooltip: 'Filtros de Catálogo',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: const EdgeInsets.all(10),
              ),
            ),
            if (hasActiveFilters)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeFiltersCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),

        // Botón Actualizar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => cubit.refreshProducts(),
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Actualizar',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  // ── BottomSheet de Filtros Móvil (Filosofía Apple HIG) ─────────────────────
  void _showMobileFiltersBottomSheet(
    AdminCatalogCubit cubit,
    AdminCatalogState state,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
          builder: (context, currentState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Apple Drag Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtros de Catálogo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              cubit.setCategory(null);
                              cubit.setStockFilter(CatalogStockFilter.all);
                              cubit.setFilterIsActive(null);
                              if (currentState.searchByIngredient) {
                                cubit.toggleSearchByIngredient(false);
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Limpiar Todo',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sección: Búsqueda por Principio Activo
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: currentState.searchByIngredient,
                        onChanged: (val) {
                          cubit.toggleSearchByIngredient(val);
                        },
                        title: const Text(
                          'Buscar por Principio Activo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Filtra por fórmula o componente farmacéutico',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        activeThumbColor: AppColors.accent,
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Disponibilidad de Stock
                      const Text(
                        'Disponibilidad de Stock',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected:
                                currentState.stockFilter ==
                                CatalogStockFilter.all,
                            onSelected: (_) {
                              cubit.setStockFilter(CatalogStockFilter.all);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('En Stock'),
                            selected:
                                currentState.stockFilter ==
                                CatalogStockFilter.inStock,
                            onSelected: (_) {
                              cubit.setStockFilter(CatalogStockFilter.inStock);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Agotados'),
                            selected:
                                currentState.stockFilter ==
                                CatalogStockFilter.outOfStock,
                            onSelected: (_) {
                              cubit.setStockFilter(
                                CatalogStockFilter.outOfStock,
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Categoría
                      const Text(
                        'Categoría',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todas'),
                              selected: currentState.selectedCategoryId == null,
                              onSelected: (_) => cubit.setCategory(null),
                            ),
                            const SizedBox(width: 8),
                            ...currentState.categories.map((cat) {
                              final isSelected =
                                  currentState.selectedCategoryId == cat.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(cat.name),
                                  selected: isSelected,
                                  onSelected:
                                      (_) => cubit.setCategory(
                                        isSelected ? null : cat.id,
                                      ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Estado de Visibilidad
                      const Text(
                        'Estado de Visibilidad',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: currentState.filterIsActive == null,
                            onSelected: (_) => cubit.setFilterIsActive(null),
                          ),
                          ChoiceChip(
                            label: const Text('Activos'),
                            selected: currentState.filterIsActive == true,
                            onSelected: (_) => cubit.setFilterIsActive(true),
                          ),
                          ChoiceChip(
                            label: const Text('Inactivos'),
                            selected: currentState.filterIsActive == false,
                            onSelected: (_) => cubit.setFilterIsActive(false),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Ordenar por
                      const Text(
                        'Ordenar por',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            CatalogSortOption.values.map((opt) {
                              return ChoiceChip(
                                label: Text(opt.label),
                                selected: currentState.sortOption == opt,
                                onSelected: (_) => cubit.setSortOption(opt),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Botón Listo
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm + 4,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Aplicar Filtros',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
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

  Widget _buildSegmentChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color:
                    isSelected
                        ? Colors.white
                        : (iconColor ?? AppColors.textSecondary),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Personalidad Desktop: Data-Grid Pro de Alta Densidad (Linear / Stripe) ─
  Widget _buildDesktopTableContainer(
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
    return Container(
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
        child: _buildBodyContent(state, cubit, isDesktop: true),
      ),
    );
  }

  // ── Personalidad Móvil: Estilo Apple / iOS Card-Based ─────────────────────
  Widget _buildMobileCardList(
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
    return _buildBodyContent(state, cubit, isDesktop: false);
  }

  // ── Gestor Unificado de Estados y Renderizado ─────────────────────────────
  Widget _buildBodyContent(
    AdminCatalogState state,
    AdminCatalogCubit cubit, {
    required bool isDesktop,
  }) {
    if (state.catalogState == ViewState.loading ||
        state.catalogState == ViewState.initial) {
      return isDesktop
          ? _buildDesktopShimmer()
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
      // 🖥️ Data-Grid Desktop Pro (Linear / Stripe style)
      final allPageSelected =
          state.products.isNotEmpty &&
          state.products.every((p) => _selectedProductIds.contains(p.id));
      final somePageSelected =
          state.products.any((p) => _selectedProductIds.contains(p.id)) &&
          !allPageSelected;

      contentList = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                // FIX CRÍTICO: Desactiva la columna automática de Flutter para evitar doble checkbox
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  AppColors.background.withValues(alpha: 0.6),
                ),
                headingRowHeight: 44,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 56,
                columnSpacing: 20,
                horizontalMargin: 16,
                showBottomBorder: true,
                columns: [
                  // Columna Única de Selección Masiva
                  DataColumn(
                    label: Checkbox(
                      value:
                          allPageSelected
                              ? true
                              : (somePageSelected ? null : false),
                      tristate: true,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (allPageSelected) {
                            for (final p in state.products) {
                              _selectedProductIds.remove(p.id);
                            }
                          } else {
                            for (final p in state.products) {
                              _selectedProductIds.add(p.id);
                            }
                          }
                        });
                      },
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'PRODUCTO',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'CATEGORÍA',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'TIPO',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'STOCK',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'ESTADO',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'ACCIONES',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                rows:
                    state.products.map((product) {
                      final isSelected = _selectedProductIds.contains(
                        product.id,
                      );
                      final activeIngredient =
                          state.matchedIngredients[product.id];
                      final variantCount = product.productVariants.length;

                      return DataRow(
                        selected: isSelected,
                        color: WidgetStateProperty.resolveWith<Color?>((
                          Set<WidgetState> states,
                        ) {
                          if (isSelected) {
                            return AppColors.primary.withValues(alpha: 0.06);
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return AppColors.primary.withValues(alpha: 0.025);
                          }
                          return null;
                        }),
                        // Clic en fila abre Linear Quick View Slide-Over
                        onSelectChanged:
                            (_) => _showProductQuickView(product, cubit),
                        cells: [
                          // Celda Única Checkbox
                          DataCell(
                            Checkbox(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProductIds.add(product.id);
                                  } else {
                                    _selectedProductIds.remove(product.id);
                                  }
                                });
                              },
                            ),
                          ),

                          // Celda Producto con Avatar, Nombre y Badge de Variantes
                          DataCell(
                            InkWell(
                              onTap:
                                  () => _showProductQuickView(product, cubit),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    _buildProductAvatar(product, size: 36),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  product.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (variantCount > 1) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.primary
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.style_outlined,
                                                        size: 10,
                                                        color: AppColors.primary,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '$variantCount var.',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (activeIngredient != null &&
                                              activeIngredient.isNotEmpty)
                                            Text(
                                              '⚗️ $activeIngredient',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            )
                                          else if (product.description !=
                                                  null &&
                                              product
                                                  .description!
                                                  .isNotEmpty)
                                            Text(
                                              product.description!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Celda Categoría
                          DataCell(
                            Text(
                              product.categoryName ?? 'Sin categoría',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),

                          // Celda Tipo
                          DataCell(_buildTypeBadge(product.productType)),

                          // Celda Stock
                          DataCell(_buildStockBadge(product.totalStock)),

                          // Celda Estado con Micro-Píldora Interactiva
                          DataCell(
                            _buildStatusPill(
                              isActive: product.isActive,
                              onTap:
                                  () => _toggleProductoActivo(product, cubit),
                            ),
                          ),

                          // Celda Acciones Discretas (Quick View + Editar + Eliminar)
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Ver Detalle y Variantes (Quick View)
                                IconButton(
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  hoverColor: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  tooltip: 'Ver Detalle y Variantes',
                                  onPressed:
                                      () =>
                                          _showProductQuickView(product, cubit),
                                ),

                                // Editar Formulario
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  hoverColor: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  tooltip: 'Editar Producto',
                                  onPressed: () {
                                    context.go(
                                      '/admin/products/product-form/${product.id}',
                                      extra: {'productToEdit': product},
                                    );
                                  },
                                ),

                                // Eliminar
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  hoverColor: AppColors.error.withValues(
                                    alpha: 0.08,
                                  ),
                                  tooltip: 'Eliminar Producto',
                                  onPressed:
                                      () => _confirmDeleteProduct(
                                        product,
                                        cubit,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          );
        },
      );
    } else {
      // 📱 Listado de Tarjetas Flotantes para Móvil (Filosofía Apple / HIG)
      contentList = ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 84),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.products.length,
        itemBuilder: (context, index) {
          final product = state.products[index];
          final activeIngredient = state.matchedIngredients[product.id];
          final variantCount = product.productVariants.length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _showProductQuickView(product, cubit),
              borderRadius: BorderRadius.circular(AppColors.radius),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.8),
                  ),
                  boxShadow: AppColors.cardShadow(opacity: 0.03),
                ),
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Monograma
                    _buildProductAvatar(product, size: 52),
                    const SizedBox(width: 14),

                    // Información Principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusPill(
                                isActive: product.isActive,
                                isDense: true,
                                onTap:
                                    () => _toggleProductoActivo(product, cubit),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                product.categoryName ?? 'Sin categoría',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (variantCount > 1) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '• $variantCount variantes',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (activeIngredient != null &&
                              activeIngredient.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '⚗️ $activeIngredient',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildStockBadge(product.totalStock),
                              const SizedBox(width: 6),
                              _buildTypeBadge(product.productType),
                              const Spacer(),
                              // Menú de opciones rápido para móvil
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                onSelected: (val) {
                                  if (val == 'view') {
                                    _showProductQuickView(product, cubit);
                                  } else if (val == 'full_detail') {
                                    context.go(
                                      '/admin/product/${product.id}',
                                      extra: product,
                                    );
                                  } else if (val == 'edit') {
                                    context.go(
                                      '/admin/products/product-form/${product.id}',
                                      extra: {'productToEdit': product},
                                    );
                                  } else if (val == 'toggle') {
                                    _toggleProductoActivo(product, cubit);
                                  } else if (val == 'delete') {
                                    _confirmDeleteProduct(product, cubit);
                                  }
                                },
                                itemBuilder:
                                    (ctx) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.visibility_outlined,
                                              size: 18,
                                              color: AppColors.textSecondary,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Vista Rápida y Variantes'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'full_detail',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.open_in_new_rounded,
                                              size: 18,
                                              color: AppColors.primary,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Ver Ficha Completa'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: AppColors.textSecondary,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Editar Producto'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Row(
                                          children: [
                                            Icon(
                                              product.isActive
                                                  ? Icons.hide_source_rounded
                                                  : Icons
                                                      .check_circle_outline_rounded,
                                              size: 18,
                                              color:
                                                  product.isActive
                                                      ? AppColors.warningDark
                                                      : AppColors.success,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              product.isActive
                                                  ? 'Desactivar'
                                                  : 'Activar',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: AppColors.error,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Eliminar Producto',
                                              style: TextStyle(
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
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

  // ── Floating Bulk Action Bar (Linear / Stripe style) ──────────────────────
  Widget _buildFloatingBulkActionBar(AdminCatalogCubit cubit, bool isDesktop) {
    return Positioned(
      bottom: isDesktop ? 24 : 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_selectedProductIds.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedProductIds.length == 1
                    ? 'seleccionado'
                    : 'seleccionados',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 10),

              // Exportar seleccionados a PDF
              TextButton.icon(
                onPressed: () => _handleBulkExportPdf(cubit),
                icon: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Exportar PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              // Botón Deseleccionar todo
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
                tooltip: 'Deseleccionar todos (Esc)',
                onPressed: () => setState(() => _selectedProductIds.clear()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Skeletons ─────────────────────────────────────────────────────────────
  Widget _buildDesktopShimmer() {
    return Column(
      children: List.generate(
        6,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const AppShimmer(width: 20, height: 20, borderRadius: 4),
              const SizedBox(width: 16),
              const AppShimmer(width: 36, height: 36, borderRadius: 10),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmer(width: 140, height: 14, borderRadius: 4),
                  SizedBox(height: 6),
                  AppShimmer(width: 200, height: 11, borderRadius: 4),
                ],
              ),
              const Spacer(),
              const AppShimmer(width: 90, height: 20, borderRadius: 6),
              const SizedBox(width: 20),
              const AppShimmer(width: 70, height: 20, borderRadius: 6),
              const SizedBox(width: 20),
              const AppShimmer(width: 60, height: 20, borderRadius: 12),
              const SizedBox(width: 20),
              const AppShimmer(width: 48, height: 20, borderRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ── Componentes de Apoyo y Diseño Atómico ───────────────────────────────
  Widget _buildProductAvatar(ProductEntity product, {required double size}) {
    final imageUrl =
        product.images.isNotEmpty
            ? product.images
                .firstWhere(
                  (img) => img.isMain,
                  orElse: () => product.images.first,
                )
                .imageUrl
            : null;

    final borderRadius = BorderRadius.circular(size > 44 ? 14 : 8);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) =>
                  _buildMonogramAvatar(product.name, size: size),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              color: AppColors.background,
              child: const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      );
    }

    return _buildMonogramAvatar(product.name, size: size);
  }

  Widget _buildMonogramAvatar(String name, {required double size}) {
    final monogram = _getMonogram(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size > 44 ? 14 : 8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      alignment: Alignment.center,
      child: Text(
        monogram,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required bool isActive,
    required VoidCallback onTap,
    bool isDense = false,
  }) {
    final bgColor =
        isActive
            ? AppColors.successLight.withValues(alpha: 0.7)
            : AppColors.slateLight.withValues(alpha: 0.5);
    final textColor =
        isActive ? AppColors.successDark : AppColors.textSecondary;
    final dotColor = isActive ? AppColors.success : AppColors.textMuted;

    return Tooltip(
      message: isActive ? 'Clic para desactivar' : 'Clic para activar',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: isDense ? 8 : 10,
              vertical: isDense ? 3 : 4.5,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isActive
                        ? AppColors.success.withValues(alpha: 0.3)
                        : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? 'Activo' : 'Inactivo',
                  style: TextStyle(
                    fontSize: isDense ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(int stock) {
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;

    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData iconData;
    String text;

    if (isOut) {
      bgColor = AppColors.dangerLight.withValues(alpha: 0.6);
      textColor = AppColors.danger;
      borderColor = AppColors.danger.withValues(alpha: 0.3);
      iconData = Icons.error_outline_rounded;
      text = 'Agotado';
    } else if (isLow) {
      bgColor = AppColors.warningLight.withValues(alpha: 0.6);
      textColor = AppColors.warningDark;
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      iconData = Icons.warning_amber_rounded;
      text = 'Bajo ($stock)';
    } else {
      bgColor = AppColors.tealLight.withValues(alpha: 0.6);
      textColor = AppColors.tealDark;
      borderColor = AppColors.teal.withValues(alpha: 0.3);
      iconData = Icons.check_circle_outline_rounded;
      text = '$stock unid.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final isMedicine = type.toLowerCase() == 'medicamento';
    final isService = type.toLowerCase() == 'servicio';

    Color textColor;
    Color bgColor;

    if (isMedicine) {
      textColor = const Color(0xFF0284C7);
      bgColor = const Color(0xFFE0F2FE);
    } else if (isService) {
      textColor = const Color(0xFF7C3AED);
      bgColor = const Color(0xFFEDE9FE);
    } else {
      textColor = AppColors.slate;
      bgColor = AppColors.slateLight.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Widget de Contenido del Quick View (Linear Slide-Over / Apple BottomSheet)
class _ProductQuickViewContent extends StatelessWidget {
  final ProductEntity product;
  final AdminCatalogCubit cubit;
  final bool isSideSheet;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onOpenFullDetail;

  const _ProductQuickViewContent({
    required this.product,
    required this.cubit,
    required this.isSideSheet,
    required this.onToggleActive,
    required this.onEdit,
    required this.onOpenFullDetail,
  });

  @override
  Widget build(BuildContext context) {
    final variants = product.productVariants;
    final primaryImg = product.primaryImageUrl;
    final displayPrice = product.displaySalePrice;
    final unitCost = product.defaultVariant?.unitCost;
    final activeIngredient =
        (product.details['active_ingredient'] ??
                product.details['active_ingredients'] ??
                product.details['principio_activo'] ??
                product.details['formula'])
            ?.toString();

    return Column(
      children: [
        // Apple Drag Handle en móvil
        if (!isSideSheet)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Ficha Rápida del Producto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Micro-píldora activo
              _QuickViewStatusPill(
                isActive: product.isActive,
                onTap: onToggleActive,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Cerrar (Esc)',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Cuerpo con Scroll
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero de Producto
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / Imagen
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          primaryImg != null && primaryImg.isNotEmpty
                              ? Image.network(
                                primaryImg,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (ctx, err, stack) =>
                                        _buildMonogram(product.name, 72),
                              )
                              : _buildMonogram(product.name, 72),
                    ),
                    const SizedBox(width: 14),

                    // Título y Categoría
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.categoryName ?? 'Sin categoría',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStockBadge(product.totalStock),
                              const SizedBox(width: 6),
                              _buildTypeBadge(product.productType),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (activeIngredient != null &&
                    activeIngredient.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Principio Activo: $activeIngredient',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // Tarjeta de Métricas Financieras y Stock
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Precio Venta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Precio Venta',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayPrice != null
                                  ? 'S/ ${displayPrice.toStringAsFixed(2)}'
                                  : 'Sin precio',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 14),

                      // Costo Ref
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Costo Ref.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unitCost != null
                                  ? 'S/ ${unitCost.toStringAsFixed(2)}'
                                  : '-',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: AppColors.border),
                      const SizedBox(width: 14),

                      // Control de Lotes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lotes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.usesBatches ? 'Activo' : 'No usa',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    product.usesBatches
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Sección Variantes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.style_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Variantes (${variants.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (variants.length > 1)
                      Text(
                        'Total: ${product.totalStock} unid.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.tealDark,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (variants.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Este producto no cuenta con variantes configuradas.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: variants.length,
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final v = variants[index];
                      return _VariantCardItem(
                        variant: v,
                        index: index,
                        isSingleVariant: variants.length == 1,
                        productStock: product.totalStock,
                      );
                    },
                  ),

                if (product.description != null &&
                    product.description!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Footer con Acciones Clave
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Editar Producto',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenFullDetail,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Ver Ficha Completa',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonogram(String name, double size) {
    final clean = name.trim();
    String initials = 'PR';
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials =
            clean.length >= 2
                ? clean.substring(0, 2).toUpperCase()
                : clean[0].toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStockBadge(int stock) {
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;

    Color bgColor;
    Color textColor;
    IconData iconData;
    String text;

    if (isOut) {
      bgColor = AppColors.dangerLight.withValues(alpha: 0.6);
      textColor = AppColors.danger;
      iconData = Icons.error_outline_rounded;
      text = 'Agotado';
    } else if (isLow) {
      bgColor = AppColors.warningLight.withValues(alpha: 0.6);
      textColor = AppColors.warningDark;
      iconData = Icons.warning_amber_rounded;
      text = 'Bajo ($stock)';
    } else {
      bgColor = AppColors.tealLight.withValues(alpha: 0.6);
      textColor = AppColors.tealDark;
      iconData = Icons.check_circle_outline_rounded;
      text = '$stock unid.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.slateLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.slate,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _VariantCardItem extends StatelessWidget {
  final ProductVariantEntity variant;
  final int index;
  final bool isSingleVariant;
  final int productStock;

  const _VariantCardItem({
    required this.variant,
    this.index = 0,
    required this.isSingleVariant,
    required this.productStock,
  });

  @override
  Widget build(BuildContext context) {
    String displayTitle;
    if (variant.attributeValues.isNotEmpty) {
      displayTitle = variant.label;
    } else if (variant.sku != null && variant.sku!.trim().isNotEmpty) {
      displayTitle = variant.sku!;
    } else if (!isSingleVariant) {
      displayTitle = 'Variante #${index + 1}';
    } else {
      displayTitle = 'Variante Estándar';
    }

    final salePrice = variant.salePrice;
    final cost = variant.unitCost;
    final wholesalePrice = variant.wholesalePrice;
    final sku = variant.sku;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Dot activo
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: variant.isActive ? AppColors.success : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Label y SKU
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (sku != null && sku.isNotEmpty && displayTitle != sku)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'SKU: $sku',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Precios
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                salePrice != null
                    ? 'S/ ${salePrice.toStringAsFixed(2)}'
                    : 'Sin precio',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (cost != null)
                Text(
                  'Costo: S/ ${cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (wholesalePrice != null)
                Text(
                  'Mayoreo: S/ ${wholesalePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickViewStatusPill extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _QuickViewStatusPill({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isActive
            ? AppColors.successLight.withValues(alpha: 0.7)
            : AppColors.slateLight.withValues(alpha: 0.5);
    final textColor =
        isActive ? AppColors.successDark : AppColors.textSecondary;
    final dotColor = isActive ? AppColors.success : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isActive
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              isActive ? 'Activo' : 'Inactivo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
