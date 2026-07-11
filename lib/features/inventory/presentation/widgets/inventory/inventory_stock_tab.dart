import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_card.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'dart:async';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';

class InventoryStockTab extends StatefulWidget {
  const InventoryStockTab({super.key});

  @override
  State<InventoryStockTab> createState() => _InventoryStockTabState();
}

class _InventoryStockTabState extends State<InventoryStockTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  ProductModel? _selectedProduct;

  @override
  bool get wantKeepAlive => true;



  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<InventoryCubit>().setStockSearch(value);
    });
  }

  Future<void> _fetchProductAndSelect(String productId) async {
    // Aquí idealmente usamos un servicio para cargar el ProductModel completo por ID.
    // Como el InventoryStockItem tiene datos parciales, delegaremos esto
    // creando un mock provisional de ProductModel o buscando en un ProductProvider,
    // pero como InventoryStockItem tiene productId, podemos llamar al Provider para obtener el producto.
    // Wait, el provider de inventario tiene `stockItems` pero no son `ProductModel`.
    // Para simplificar, ProductDetailScreen requiere un ProductModel completo.
    // Vamos a buscar el producto usando el InventoryProvider o un servicio.
    try {
      // NOTE: This functionality should probably be moved to a UseCase
      // or handled differently in the Cubit. For now we will assume the selected product
      // logic is simplified or we fetch it from the catalog module's repository directly.
      // Final Implementation requires fetching ProductModel, which is out of scope of this tab.
      // To not break the code, we just simulate loading for now:
      if (mounted) {
        setState(() {
          //_selectedProduct = null; // Update logic later if needed
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar producto: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        if (state is InventoryInitial || state is InventoryLoading && state is! InventoryLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final loadedState = state is InventoryLoaded 
          ? state 
          : (state is InventoryLoading 
              ? context.read<InventoryCubit>().state as InventoryLoaded? // Try to get previous loaded state
              : null);

        if (loadedState == null && state is InventoryError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        final currentState = loadedState ?? const InventoryLoaded(
          stockItems: [], batchItems: [], currentStockPage: 0, totalStockPages: 1, 
          stockSearchText: '', stockCategoryFilter: 'Todos', categories: ['Todos'], 
          globalTotalVariants: 0, globalTotalStock: 0, globalLowStockCount: 0, globalTotalCost: 0.0, 
          currentBatchPage: 0, totalBatchPages: 1, batchSearchText: '', batchStatusFilter: 'Todos', 
          countVencido: 0, countCritico: 0, countProximo: 0, countNormal: 0,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 800;

            if (isTablet) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: _buildListContent(currentState, state is InventoryLoading, isTablet: true),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child:
                        _selectedProduct == null
                            ? Container(
                              color: AppColors.background,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: AppColors.border,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Selecciona un producto para ver sus detalles',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : ProductDetailScreen(
                              key: ValueKey('product_${_selectedProduct!.id}'),
                              product: _selectedProduct!.toEntity(),
                              isAdmin: true,
                              isEmbedded: true,
                            ),
                  ),
                ],
              );
            }

            return _buildListContent(currentState, state is InventoryLoading, isTablet: false);
          },
        );
      },
    );
  }

  Widget _buildListContent(
    InventoryLoaded state,
    bool isLoading, {
    required bool isTablet,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Métricas ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _MetricCard(
                  label: 'Valor Inv.',
                  value: 'S/ ${state.globalTotalCost.toStringAsFixed(2)}',
                  icon: Icons.monetization_on_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Stock total',
                  value: '${state.globalTotalStock}',
                  icon: Icons.inventory_rounded,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 8),
                _MetricCard(
                  label: 'Bajo stock',
                  value: '${state.globalLowStockCount}',
                  icon: Icons.warning_amber_rounded,
                  color:
                      state.globalLowStockCount > 0
                          ? AppColors.warning
                          : AppColors.success,
                  highlight: state.globalLowStockCount > 0,
                ),
              ],
            ),
          ),
        ),

        // ── Filtros Sticky ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyStockFiltersDelegate(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchField(
                    controller: _searchCtrl,
                    hint: 'Buscar producto o SKU...',
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchCtrl.clear();
                      context.read<InventoryCubit>().setStockSearch('');
                    },
                    onScan: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'La función de escáner QR estará disponible pronto.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  if (state.categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            state.categories.map((cat) {
                              final isSelected =
                                  cat == state.stockCategoryFilter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _CategoryPill(
                                  label: cat,
                                  isSelected: isSelected,
                                  onTap: () => context.read<InventoryCubit>().setStockCategory(cat),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Resumen Resultados ──
        if (!isLoading && state.stockItems.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Resultados',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${(state.currentStockPage * 8) + 1}–${((state.currentStockPage * 8) + state.stockItems.length)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Lista Principal ──
        if (isLoading && state.stockItems.isEmpty)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _InventoryStockSkeleton()),
          )
        else if (state.stockItems.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Sin Resultados',
              message: 'No hay productos con stock disponible',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              state.totalStockPages > 1 ? 100 : 16,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final item = state.stockItems[i];
                final isSelected =
                    isTablet && _selectedProduct?.id == item.productId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InventoryStockCard(
                    item: item,
                    isSelected: isSelected,
                    onTap:
                        isTablet
                            ? () => _fetchProductAndSelect(item.productId)
                            : null, // Deja null para usar default que hace context.push
                  ),
                );
              }, childCount: state.stockItems.length),
            ),
          ),

        // ── Paginación ──
        if (!isLoading && state.totalStockPages > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AdminPageBlocks(
                currentPage: state.currentStockPage,
                totalPages: state.totalStockPages,
                onPageChanged: (page) => context.read<InventoryCubit>().setStockPage(page),
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DELEGATES
// ══════════════════════════════════════════════════════════════════════════════

class _StickyStockFiltersDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyStockFiltersDelegate({required this.child});

  @override
  double get minExtent => 130.0;
  @override
  double get maxExtent => 130.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyStockFiltersDelegate oldDelegate) {
    return true;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ══════════════════════════════════════════════════════════════════════════════

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                highlight
                    ? [color.withValues(alpha: 0.9), color]
                    : [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                    ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ? color : color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: highlight ? Colors.white : color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          highlight
                              ? Colors.white.withValues(alpha: 0.9)
                              : color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: highlight ? Colors.white : color,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onScan;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.textSecondary,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: onClear,
              ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              color: AppColors.primary,
              onPressed: onScan,
            ),
          ],
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryStockSkeleton extends StatelessWidget {
  const _InventoryStockSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const AppShimmer(width: 56, height: 56, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmer(width: 150, height: 16, borderRadius: 4),
                    SizedBox(height: 6),
                    AppShimmer(width: 100, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    AppShimmer(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  AppShimmer(width: 60, height: 24, borderRadius: 12),
                  SizedBox(height: 8),
                  AppShimmer(width: 40, height: 14, borderRadius: 4),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
