import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_status_states.dart';

class SearchIntent extends Intent {
  const SearchIntent();
}

class NewProductIntent extends Intent {
  const NewProductIntent();
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

  Future<void> _confirmDeleteProduct(ProductEntity product, AdminCatalogCubit cubit) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro de que deseas eliminar "${product.name}"? Esta acción no se puede deshacer y fallará si el producto tiene stock o ventas asociadas.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusLg)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
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
        AppSnackbar.show(
          context,
          message: 'Producto eliminado correctamente',
          type: SnackbarType.success,
        );
      }
    }
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
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const NewProductIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const NewProductIntent(),
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
                // Éxito manejado individualmente
              }
            },
            child: AdminLayout(
              title: 'Inventario de Productos',
              showBackButton: true,
              actions: [
                if (!isDesktop)
                  IconButton(
                    icon: const Icon(Icons.upload_file_rounded),
                    tooltip: 'Importar Lote (CSV)',
                    onPressed: () => context.go('/admin/products/bulk-import'),
                  ),
                if (isDesktop) ...[
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/products/bulk-import'),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text(
                      'Importar Lote (CSV)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/products/product-form'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Nuevo Producto (Ctrl+N)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

                  return Container(
                    color: AppColors.background,
                    padding: EdgeInsets.all(isDesktopLayout ? 24.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Barra de Búsqueda y Filtros ────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radius,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchCtrl,
                                  focusNode: _searchFocusNode,
                                  onChanged: cubit.setSearchTerm,
                                  decoration: InputDecoration(
                                    hintText:
                                        isDesktopLayout
                                            ? 'Buscar por nombre, código o SKU... (Ctrl+F)'
                                            : 'Buscar por nombre...',
                                    hintStyle: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: AppColors.textMuted,
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isDesktopLayout)
                              OutlinedButton.icon(
                                onPressed: () => cubit.refreshProducts(),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                label: const Text('Actualizar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppColors.radius,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radius,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () => cubit.refreshProducts(),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: AppColors.textPrimary,
                                    size: 20,
                                  ),
                                  tooltip: 'Actualizar',
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Contenido Camaleónico (Desktop vs Mobile) ──────────
                        Expanded(
                          child:
                              BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                                buildWhen:
                                    (previous, current) =>
                                        previous.catalogState != current.catalogState ||
                                        previous.products != current.products ||
                                        previous.actionState != current.actionState ||
                                        previous.errorMessage != current.errorMessage,
                                builder: (context, state) {
                                  final content = isDesktopLayout
                                      ? _buildDesktopTableContainer(
                                        state,
                                        cubit,
                                      )
                                      : _buildMobileCardList(state, cubit);

                                  return Stack(
                                    children: [
                                      content,
                                      if (state.actionState == ViewState.loading)
                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Personalidad Desktop: Estilo ERP de Alta Densidad ─────────────────────
  Widget _buildDesktopTableContainer(
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
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
            itemBuilder:
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppShimmer(
                    width: double.infinity,
                    height: 100,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No se encontraron productos registrados',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    Widget contentList;
    if (isDesktop) {
      contentList = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AppColors.background.withValues(alpha: 0.5),
                ),
                dataRowMinHeight: 68,
                dataRowMaxHeight: 68,
                columnSpacing: 24,
                showBottomBorder: true,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Producto',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Categoría',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Tipo',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Stock',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Estado',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Acciones',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                rows:
                    state.products.map((product) {
                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>((
                          Set<WidgetState> states,
                        ) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppColors.primary.withValues(alpha: 0.04);
                          }
                          return null;
                        }),
                        onSelectChanged: (_) {
                          context.go(
                            '/admin/products/product-form/${product.id}',
                            extra: {'productToEdit': product},
                          );
                        },
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                _buildProductAvatar(product, size: 44),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (product.description != null &&
                                        product.description!.isNotEmpty)
                                      SizedBox(
                                        width: 240,
                                        child: Text(
                                          product.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              product.categoryName ?? 'Sin categoría',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          DataCell(_buildTypeBadge(product.productType)),
                          DataCell(_buildStockBadge(product.totalStock)),
                          DataCell(
                            Switch.adaptive(
                              value: product.isActive,
                              activeThumbColor: AppColors.success,
                              onChanged:
                                  (_) => _toggleProductoActivo(product, cubit),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  hoverColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  tooltip: 'Editar Producto',
                                  onPressed: () {
                                    context.go(
                                      '/admin/products/product-form/${product.id}',
                                      extra: {'productToEdit': product},
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: AppColors.error,
                                  ),
                                  hoverColor: AppColors.error.withValues(
                                    alpha: 0.1,
                                  ),
                                  tooltip: 'Eliminar Producto',
                                  onPressed: () => _confirmDeleteProduct(product, cubit),
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
        padding: const EdgeInsets.only(bottom: 80),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.products.length,
        itemBuilder: (context, index) {
          final product = state.products[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              onTap: () {
                context.go(
                  '/admin/products/product-form/${product.id}',
                  extra: {'productToEdit': product},
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProductAvatar(product, size: 56),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.categoryName ?? 'Sin categoría',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildStockBadge(product.totalStock),
                                const SizedBox(width: 8),
                                _buildTypeBadge(product.productType),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Switch.adaptive(
                            value: product.isActive,
                            activeThumbColor: AppColors.success,
                            onChanged:
                                (_) => _toggleProductoActivo(product, cubit),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDeleteProduct(product, cubit),
                          ),
                        ],
                      ),
                    ],
                  ),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
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

  // ── Skeletons ─────────────────────────────────────────────────────────────
  Widget _buildDesktopShimmer() {
    return Column(
      children: List.generate(
        6,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              AppShimmer(width: 44, height: 44, borderRadius: 10),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmer(width: 120, height: 16, borderRadius: 4),
                  const SizedBox(height: 8),
                  AppShimmer(width: 200, height: 12, borderRadius: 4),
                ],
              ),
              const Spacer(),
              AppShimmer(width: 80, height: 24, borderRadius: 12),
              const SizedBox(width: 24),
              AppShimmer(width: 60, height: 24, borderRadius: 12),
              const SizedBox(width: 24),
              AppShimmer(width: 40, height: 20, borderRadius: 10),
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

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        image:
            imageUrl != null
                ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child:
          imageUrl == null
              ? Icon(
                Icons.image_not_supported_outlined,
                size: size * 0.45,
                color: AppColors.textMuted,
              )
              : null,
    );
  }

  Widget _buildStockBadge(int stock) {
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;

    Color bgColor;
    Color textColor;
    IconData iconData;

    if (isOut) {
      bgColor = AppColors.error.withValues(alpha: 0.1);
      textColor = AppColors.error;
      iconData = Icons.error_outline_rounded;
    } else if (isLow) {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange.shade800;
      iconData = Icons.warning_amber_rounded;
    } else {
      bgColor = AppColors.success.withValues(alpha: 0.1);
      textColor = AppColors.success;
      iconData = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            isOut ? 'Agotado' : (isLow ? 'Bajo ($stock)' : 'Stock: $stock'),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            type.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
