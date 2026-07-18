import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_tab.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batches_tab.dart';

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
    return Column(
      children: [
        // ── Tab Bar ──
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.inventory_2_rounded, size: 20),
                text: 'Stock General',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                icon: Icon(Icons.event_busy_rounded, size: 20),
                text: 'Estado de Lotes',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
            ],
          ),
        ),

        // ── Tab Views ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [InventoryStockTab(), InventoryBatchesTab()],
          ),
        ),
      ],
    );
  }
}
