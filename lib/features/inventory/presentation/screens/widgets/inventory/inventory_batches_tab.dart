import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/widgets/inventory/inventory_batch_card.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'dart:async';
import 'package:inventory_store_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';

class InventoryBatchesTab extends StatefulWidget {
  const InventoryBatchesTab({super.key});

  @override
  State<InventoryBatchesTab> createState() => _InventoryBatchesTabState();
}

class _InventoryBatchesTabState extends State<InventoryBatchesTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  ProductModel? _selectedProduct;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().initBatchesTab();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<InventoryProvider>().setBatchSearch(value);
    });
  }

  Future<void> _fetchProductAndSelect(String productId) async {
    try {
      final product = await context.read<InventoryProvider>().fetchProductById(
        productId,
      );
      if (mounted && product != null) {
        setState(() {
          _selectedProduct = product;
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
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
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
                      child: _buildListContent(provider, isTablet: true),
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
                                      'Selecciona un lote para ver los detalles del producto',
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
                              product: _selectedProduct!,
                              isAdmin: true,
                              isEmbedded: true,
                            ),
                  ),
                ],
              );
            }

            return _buildListContent(provider, isTablet: false);
          },
        );
      },
    );
  }

  Widget _buildListContent(
    InventoryProvider provider, {
    required bool isTablet,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Métricas de Lotes ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _MetricCard(
                  label: 'Vencidos',
                  value: '${provider.countVencido}',
                  icon: Icons.block_rounded,
                  color: AppColors.danger,
                  highlight: provider.countVencido > 0,
                ),
                const SizedBox(width: 6),
                _MetricCard(
                  label: 'Críticos',
                  value: '${provider.countCritico}',
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  highlight: provider.countCritico > 0,
                ),
                const SizedBox(width: 6),
                _MetricCard(
                  label: 'Próximos',
                  value: '${provider.countProximo}',
                  icon: Icons.schedule_rounded,
                  color: Colors.blue.shade400,
                  highlight: provider.countProximo > 0,
                ),
                const SizedBox(width: 6),
                _MetricCard(
                  label: 'Normal',
                  value: '${provider.countNormal}',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ),

        // ── Filtros Sticky ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyBatchesFiltersDelegate(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchField(
                    controller: _searchCtrl,
                    hint: 'Buscar por producto o lote...',
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchCtrl.clear();
                      provider.setBatchSearch('');
                    },
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatusPill(
                          label: 'Todos',
                          isSelected: provider.batchStatusFilter == 'Todos',
                          onTap: () => provider.setBatchStatus('Todos'),
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: 'Vencidos',
                          isSelected: provider.batchStatusFilter == 'vencido',
                          onTap: () => provider.setBatchStatus('vencido'),
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: 'Críticos',
                          isSelected: provider.batchStatusFilter == 'critico',
                          onTap: () => provider.setBatchStatus('critico'),
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: 'Próximos',
                          isSelected: provider.batchStatusFilter == 'proximo',
                          onTap: () => provider.setBatchStatus('proximo'),
                          color: Colors.blue.shade400,
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(
                          label: 'Normales',
                          isSelected: provider.batchStatusFilter == 'normal',
                          onTap: () => provider.setBatchStatus('normal'),
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Resumen Resultados ──
        if (!provider.isLoadingBatches && provider.batchItems.isNotEmpty)
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
                    '${(provider.currentBatchPage * InventoryProvider.batchPageSize) + 1}–${((provider.currentBatchPage * InventoryProvider.batchPageSize) + provider.batchItems.length).clamp(0, provider.totalBatchItems)} de ${provider.totalBatchItems}',
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
        if (provider.isLoadingBatches)
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _InventoryBatchesSkeleton()),
          )
        else if (provider.errorMessageBatches.isNotEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.error_outline_rounded,
              color: Colors.red,
              title: 'Error',
              message: provider.errorMessageBatches,
            ),
          )
        else if (provider.batchItems.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Sin Resultados',
              message: 'No se encontraron lotes con estos criterios',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              provider.totalBatchPages > 1 ? 100 : 16,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, i) {
                final batch = provider.batchItems[i];
                final isSelected =
                    isTablet && _selectedProduct?.id == batch.productId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InventoryBatchCard(
                    batch: batch,
                    isSelected: isSelected,
                    onTap:
                        isTablet
                            ? () => _fetchProductAndSelect(batch.productId)
                            : null,
                  ),
                );
              }, childCount: provider.batchItems.length),
            ),
          ),

        // ── Paginación ──
        if (!provider.isLoadingBatches && provider.totalBatchPages > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: AdminPageBlocks(
                currentPage: provider.currentBatchPage,
                totalPages: provider.totalBatchPages,
                onPageChanged: (page) => provider.setBatchPage(page),
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

class _StickyBatchesFiltersDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyBatchesFiltersDelegate({required this.child});

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
  bool shouldRebuild(_StickyBatchesFiltersDelegate oldDelegate) {
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: highlight ? Colors.white : color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
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

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
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
        suffixIcon:
            controller.text.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: onClear,
                )
                : null,
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

class _StatusPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
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
            color: isSelected ? color : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.1),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryBatchesSkeleton extends StatelessWidget {
  const _InventoryBatchesSkeleton();

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
