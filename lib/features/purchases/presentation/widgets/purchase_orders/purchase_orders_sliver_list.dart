import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_table_view.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_view_model.dart';

/// Sliver adaptativo para mostrar órdenes de compra según la vista y dispositivo:
/// - Shimmer sólo en primer arranque en frío sin caché previa (Zero-Shimmer Frame-0)
/// - Empty state cuando no hay registros para los filtros actuales
/// - Tabla profesional en desktop/tablet (`PurchaseOrdersTableView`)
/// - Grid bento de 2 columnas en tablet
/// - Lista de tarjetas en móviles (`POCard`)
class PurchaseOrdersSliverList extends StatelessWidget {
  final PurchaseOrdersViewModel viewModel;
  final List<PurchaseOrderModel> displayOrders;
  final List<PurchaseOrderModel> filteredOrders;
  final PurchaseOrderModel? selectedOrder;
  final bool isTablet;
  final bool isTableView;
  final ValueChanged<PurchaseOrderModel> onSelectOrder;
  final VoidCallback onRefresh;

  const PurchaseOrdersSliverList({
    super.key,
    required this.viewModel,
    required this.displayOrders,
    required this.filteredOrders,
    required this.selectedOrder,
    required this.isTablet,
    required this.isTableView,
    required this.onSelectOrder,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasCachedOrders = filteredOrders.isNotEmpty;
    if (viewModel.isLoading && !hasCachedOrders) {
      if (isTableView && isTablet) {
        return const SliverToBoxAdapter(child: AppTableShimmer());
      }
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: AppShimmer(
              width: double.infinity,
              height: 90,
              borderRadius: 16,
            ),
          ),
          childCount: 5,
        ),
      );
    }

    if (filteredOrders.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Sin Resultados',
          message: 'Sin resultados para los filtros aplicados',
        ),
      );
    }

    if (isTableView && isTablet) {
      return SliverToBoxAdapter(
        child: PurchaseOrdersTableView(
          key: ValueKey(
            'table_${viewModel.statusFilter}_${viewModel.currentPage}',
          ),
          orders: displayOrders,
          selectedOrder: selectedOrder,
          onSelectOrder: onSelectOrder,
          onRefresh: onRefresh,
        ),
      );
    }

    if (isTablet) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final po = displayOrders[index];
          final isSel = selectedOrder?.id == po.id;
          return RepaintBoundary(
            child: POCard(
              po: po,
              isSelected: isSel,
              onTap: () => onSelectOrder(po),
            ),
          );
        }, childCount: displayOrders.length),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final po = displayOrders[index];
        final isSel = isTablet && selectedOrder?.id == po.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RepaintBoundary(
            child: POCard(
              po: po,
              isSelected: isSel,
              onTap: () => onSelectOrder(po),
            ),
          ),
        );
      }, childCount: displayOrders.length),
    );
  }
}
