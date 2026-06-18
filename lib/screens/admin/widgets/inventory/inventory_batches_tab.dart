import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/inventory_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/inventory/inventory_batch_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'dart:async';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class InventoryBatchesTab extends StatefulWidget {
  const InventoryBatchesTab({super.key});

  @override
  State<InventoryBatchesTab> createState() => _InventoryBatchesTabState();
}

class _InventoryBatchesTabState extends State<InventoryBatchesTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // ── Chips de estado ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _StatusChip(
                    label: 'Vencido',
                    count: provider.countVencido,
                    color: AppColors.danger,
                    selected: provider.batchStatusFilter == 'Vencido',
                    onTap:
                        () => provider.setBatchStatus(
                          provider.batchStatusFilter == 'Vencido'
                              ? 'Todos'
                              : 'Vencido',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '≤30 días',
                    count: provider.countCritico,
                    color: AppColors.warning,
                    selected: provider.batchStatusFilter == 'Crítico',
                    onTap:
                        () => provider.setBatchStatus(
                          provider.batchStatusFilter == 'Crítico'
                              ? 'Todos'
                              : 'Crítico',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: '≤90 días',
                    count: provider.countProximo,
                    color: Colors.orange.shade400,
                    selected: provider.batchStatusFilter == 'Próximo',
                    onTap:
                        () => provider.setBatchStatus(
                          provider.batchStatusFilter == 'Próximo'
                              ? 'Todos'
                              : 'Próximo',
                        ),
                  ),
                  const SizedBox(width: 6),
                  _StatusChip(
                    label: 'Normal',
                    count: provider.countNormal,
                    color: AppColors.success,
                    selected: provider.batchStatusFilter == 'Normal',
                    onTap:
                        () => provider.setBatchStatus(
                          provider.batchStatusFilter == 'Normal'
                              ? 'Todos'
                              : 'Normal',
                        ),
                  ),
                ],
              ),
            ),

            // ── Búsqueda ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto o lote...',
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
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: AppColors.textSecondary,
                            onPressed: () {
                              _searchCtrl.clear();
                              provider.setBatchSearch('');
                            },
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 20,
                          ),
                          color: AppColors.primary,
                          onPressed: () {
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
              ),
            ),

            if (!provider.isLoadingBatches && provider.batchItems.isNotEmpty)
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

            Expanded(
              child:
                  provider.isLoadingBatches
                      ? const _InventoryBatchesSkeleton()
                      : provider.errorMessageBatches.isNotEmpty
                      ? AppEmptyState(
                        icon: Icons.error_outline_rounded,
                        color: Colors.red,
                        title: 'Error',
                        message: provider.errorMessageBatches,
                      )
                      : provider.batchItems.isEmpty
                      ? AppEmptyState(
                        icon: Icons.event_available_rounded,
                        title: 'Sin Resultados',
                        message: 'No hay lotes con stock disponible',
                      )
                      : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => provider.fetchBatchPage(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: provider.batchItems.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 10),
                          itemBuilder:
                              (_, i) => InventoryBatchCard(
                                batch: provider.batchItems[i],
                              ),
                        ),
                      ),
            ),

            if (!provider.isLoadingBatches && provider.totalBatchPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: AdminPageBlocks(
                  currentPage: provider.currentBatchPage,
                  totalPages: provider.totalBatchPages,
                  onPageChanged: (page) => provider.setBatchPage(page),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
              boxShadow:
                  selected
                      ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color:
                        selected
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textSecondary,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppShimmer(width: 44, height: 44, borderRadius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 130, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        AppShimmer(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      AppShimmer(width: 60, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      AppShimmer(width: 50, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  AppShimmer(width: 90, height: 26, borderRadius: 13),
                  AppShimmer(width: 120, height: 12, borderRadius: 4),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
