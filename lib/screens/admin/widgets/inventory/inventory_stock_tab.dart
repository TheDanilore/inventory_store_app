import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/inventory/inventory_stock_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'dart:async';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class InventoryStockTab extends StatefulWidget {
  const InventoryStockTab({super.key});

  @override
  State<InventoryStockTab> createState() => _InventoryStockTabState();
}

class _InventoryStockTabState extends State<InventoryStockTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().initStockTab();
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
      context.read<InventoryProvider>().setStockSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // ── Métricas ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _MetricCard(
                    label: 'Variantes',
                    value: '${provider.globalTotalVariants}',
                    icon: Icons.layers_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _MetricCard(
                    label: 'Stock total',
                    value: '${provider.globalTotalStock}',
                    icon: Icons.inventory_rounded,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 10),
                  _MetricCard(
                    label: 'Bajo stock',
                    value: '${provider.globalLowStockCount}',
                    icon: Icons.warning_amber_rounded,
                    color:
                        provider.globalLowStockCount > 0
                            ? AppColors.warning
                            : AppColors.success,
                    highlight: provider.globalLowStockCount > 0,
                  ),
                ],
              ),
            ),

            // ── Búsqueda ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _SearchField(
                controller: _searchCtrl,
                hint: 'Buscar producto o SKU...',
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchCtrl.clear();
                  provider.setStockSearch('');
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
            ),

            // ── Filtro de Categorías (Pills) ──
            if (provider.categories.isNotEmpty)
              Container(
                height: 38,
                margin: const EdgeInsets.only(top: 12),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = provider.categories[index];
                    final isSelected = cat == provider.stockCategoryFilter;
                    return _CategoryPill(
                      label: cat,
                      isSelected: isSelected,
                      onTap: () => provider.setStockCategory(cat),
                    );
                  },
                ),
              ),

            if (!provider.isLoadingStock && provider.stockItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resultados',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(provider.currentStockPage * InventoryProvider.stockPageSize) + 1}–${((provider.currentStockPage * InventoryProvider.stockPageSize) + provider.stockItems.length).clamp(0, provider.totalStockItems)} de ${provider.totalStockItems}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child:
                  provider.isLoadingStock
                      ? const _InventoryStockSkeleton()
                      : provider.errorMessageStock.isNotEmpty
                      ? AppEmptyState(
                        icon: Icons.error_outline_rounded,
                        color: Colors.red,
                        title: 'Error',
                        message: provider.errorMessageStock,
                      )
                      : provider.stockItems.isEmpty
                      ? AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Sin Resultados',
                        message: 'No hay productos con stock disponible',
                      )
                      : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => provider.fetchStockPage(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: provider.stockItems.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 10),
                          itemBuilder:
                              (_, i) => InventoryStockCard(
                                item: provider.stockItems[i],
                              ),
                        ),
                      ),
            ),

            if (!provider.isLoadingStock && provider.totalStockPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: AdminPageBlocks(
                  currentPage: provider.currentStockPage,
                  totalPages: provider.totalStockPages,
                  onPageChanged: (page) => provider.setStockPage(page),
                ),
              ),
          ],
        );
      },
    );
  }
}

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
          color: highlight ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: highlight ? color : AppColors.border),
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
                              : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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
                color: highlight ? Colors.white : AppColors.textPrimary,
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
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
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
              const SizedBox(width: 4),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
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
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      physics: const NeverScrollableScrollPhysics(),
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
