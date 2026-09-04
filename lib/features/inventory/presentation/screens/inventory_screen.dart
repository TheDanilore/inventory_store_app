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
              // ── Header Segmented Pill Bar (Estilo Stripe / Linear) ──
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
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
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
                  ),
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
