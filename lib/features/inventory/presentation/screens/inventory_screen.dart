import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_tab.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batches_tab.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      // Lazy load de la pestaña de lotes
      context.read<InventoryCubit>().initBatchesTab();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Inventario',
      showBackButton: true,
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          int urgentCount = 0;
          if (state is InventoryLoaded) {
            urgentCount = state.countVencido + state.countCritico;
          }

          return Column(
            children: [
              // ── Header Segmented Pill Bar & Warehouse Selector ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 740;
                    final tabBarWidget = Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: AppColors.cardShadow(opacity: 0.04),
                        ),
                        dividerColor: Colors.transparent,
                        labelColor: AppColors.textPrimary,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        tabs: [
                          const Tab(
                            height: 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Stock General'),
                              ],
                            ),
                          ),
                          Tab(
                            height: 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.event_busy_rounded, size: 16),
                                const SizedBox(width: 8),
                                const Text('Estado de Lotes'),
                                if (urgentCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$urgentCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                    final warehouseSelector = _WarehouseSelector(
                      state: state is InventoryLoaded ? state : null,
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(child: tabBarWidget),
                          const SizedBox(height: 8),
                          warehouseSelector,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        tabBarWidget,
                        warehouseSelector,
                      ],
                    );
                  },
                ),
              ),

              // ── Tab Views ──
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    InventoryStockTab(),
                    InventoryBatchesTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WarehouseSelector extends StatelessWidget {
  final InventoryLoaded? state;

  const _WarehouseSelector({this.state});

  @override
  Widget build(BuildContext context) {
    final warehouses = state?.warehouses ?? [];
    final selectedId = state?.selectedWarehouseId;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 18,
            color: selectedId != null ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          const Text(
            'Almacén:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: selectedId,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              borderRadius: BorderRadius.circular(10),
              dropdownColor: AppColors.surface,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Todos los almacenes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...warehouses.map((wh) {
                  return DropdownMenuItem<String?>(
                    value: wh.id,
                    child: Text(
                      wh.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (newWarehouseId) {
                String whName = 'Todos los almacenes';
                if (newWarehouseId != null) {
                  final found = warehouses.where((w) => w.id == newWarehouseId);
                  if (found.isNotEmpty) {
                    whName = found.first.name;
                  }
                }
                context.read<InventoryCubit>().setWarehouseFilter(
                  newWarehouseId,
                  whName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
