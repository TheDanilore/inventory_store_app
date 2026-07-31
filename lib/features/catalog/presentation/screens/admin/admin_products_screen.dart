import 'package:flutter/material.dart';
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

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchCtrl.text = context.read<AdminCatalogCubit>().state.searchTerm;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleProductoActivo(
    ProductEntity product,
    AdminCatalogCubit cubit,
  ) async {
    final willActivate = !product.isActive;
    final success = await cubit.toggleProductActive(product);

    if (success && mounted) {
      AppSnackbar.show(
        context,
        message:
            willActivate
                ? '${product.name} ha sido activado'
                : '${product.name} ha sido desactivado',
        type: SnackbarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCatalogCubit>();

    return AdminLayout(
      title: 'Inventario de Productos',
      showBackButton: false,
      actions: [
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
            'Nuevo Producto',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Container(
            color: AppColors.background,
            padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
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
                          borderRadius: BorderRadius.circular(AppColors.radius),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.cardShadow(),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: cubit.setSearchTerm,
                          decoration: const InputDecoration(
                            hintText: 'Buscar por nombre, código o SKU...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.textMuted,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => cubit.refreshProducts(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label:
                          isDesktop
                              ? const Text('Actualizar')
                              : const SizedBox.shrink(),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 16 : 14,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radius),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Contenido Camaleónico (Desktop vs Mobile) ──────────
                Expanded(
                  child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
                    builder: (context, state) {
                      return isDesktop
                          ? _buildDesktopTableContainer(state, cubit)
                          : _buildMobileCardList(state, cubit);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Personalidad Desktop: Estilo ERP de Alta Densidad ─────────────────────
  // ── Personalidad Desktop: Estilo ERP de Alta Densidad ─────────────────────
  Widget _buildDesktopTableContainer(
    AdminCatalogState state,
    AdminCatalogCubit cubit,
  ) {
    return Container(
      width: double.infinity, // <-- Forzar ancho total
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(),
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
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
            itemCount: 6,
            itemBuilder:
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppShimmer(
                    width: double.infinity,
                    height: 90,
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
                headingRowColor: WidgetStateProperty.all(AppColors.background),
                dataRowMinHeight: 64,
                dataRowMaxHeight: 64,
                columnSpacing: 24,
                columns: const [
                  DataColumn(
                    label: Text(
                      'Producto',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Categoría',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Tipo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Stock',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Estado',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Acciones',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                rows:
                    state.products.map((product) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                _buildProductAvatar(product, size: 40),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
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
                              style: const TextStyle(fontSize: 13),
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
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Editar',
                              onPressed: () {
                                context.go(
                                  '/admin/products/product-form/${product.id}',
                                  extra: {'productToEdit': product},
                                );
                              },
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
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.products.length,
        itemBuilder: (context, index) {
          final product = state.products[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  _buildProductAvatar(product, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Switch.adaptive(
                              value: product.isActive,
                              activeThumbColor: AppColors.success,
                              onChanged:
                                  (_) => _toggleProductoActivo(product, cubit),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.categoryName ?? 'Sin categoría',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStockBadge(product.totalStock),
                            const SizedBox(width: 8),
                            _buildTypeBadge(product.productType),
                            const Spacer(),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.edit_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              onPressed: () {
                                context.go(
                                  '/admin/products/product-form/${product.id}',
                                  extra: {'productToEdit': product},
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
        color: AppColors.border.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isOut
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOut ? 'Agotado (0)' : 'Stock: $stock',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isOut ? AppColors.error : AppColors.success,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
