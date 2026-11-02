import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_state.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/admin_order_card.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/orders_table_view.dart';

/// Sliver adaptativo para mostrar pedidos según dispositivo y vista:
/// - Shimmer sólo en primer arranque en frío sin caché previa (Zero-Shimmer Frame-0)
/// - Empty state cuando no hay pedidos para los filtros actuales
/// - Tabla profesional en desktop/tablet (`OrdersTableView`)
/// - Grid bento de tarjetas en tablet/desktop (`AdminOrderCard`)
/// - Lista vertical optimizada en móviles (`AdminOrderCard`)
class OrdersSliverList extends StatelessWidget {
  final OrdersState state;
  final OrdersCubit cubit;
  final bool isWide;
  final bool isTableView;
  final bool isLoyaltyEnabled;
  final OrderEntity? selectedOrder;
  final List<OrderEntity> displayOrders;
  final ValueChanged<OrderEntity> onSelectOrder;
  final ValueChanged<OrderEntity> onPrintTicket;
  final void Function(OrderEntity, String) onUpdateStatus;

  const OrdersSliverList({
    super.key,
    required this.state,
    required this.cubit,
    required this.isWide,
    required this.isTableView,
    required this.isLoyaltyEnabled,
    required this.selectedOrder,
    required this.displayOrders,
    required this.onSelectOrder,
    required this.onPrintTicket,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final pageItems = displayOrders;
    final hasCachedData = pageItems.isNotEmpty;

    // Zero-Shimmer Policy: Mostrar Shimmer SOLAMENTE en Cold Start si no hay datos en memoria/caché
    if (state.isLoading && !hasCachedData) {
      if (isTableView && isWide) {
        return const SliverToBoxAdapter(child: AppTableShimmer());
      }
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppShimmer(height: 120),
          ),
          childCount: 5,
        ),
      );
    }

    if (state.errorMessage.isNotEmpty && pageItems.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.error_outline_rounded,
          color: AppColors.error,
          title: 'Ocurrió un error',
          message: state.errorMessage,
          action: FilledButton.icon(
            onPressed: () => cubit.loadOrders(reset: true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
          ),
        ),
      );
    }

    if (pageItems.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No se encontraron pedidos.',
          message: 'Intenta cambiar los filtros o la búsqueda.',
        ),
      );
    }

    // Modo Tabla Profesional en Desktop/Tablet
    if (isWide && isTableView) {
      return SliverToBoxAdapter(
        child: OrdersTableView(
          orders: pageItems,
          selectedOrder: selectedOrder,
          onSelectOrder: onSelectOrder,
          onPrintTicket: onPrintTicket,
          onUpdateStatus: onUpdateStatus,
          isProcessing: state.isBackgroundLoading,
        ),
      );
    }

    // Modo Grid en Desktop / Tablet
    if (isWide) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final order = pageItems[index];
          final isSelected = selectedOrder?.id == order.id;

          return RepaintBoundary(
            child: AdminOrderCard(
              order: order,
              isProcessing:
                  cubit.state.isOrderProcessing(order.id) ||
                  state.isBackgroundLoading,
              isGeneratingPDF: state.isGeneratingPDF(order.id),
              isSelected: isSelected,
              isLoyaltyEnabled: isLoyaltyEnabled,
              onTap: () => onSelectOrder(order),
              onUpdateStatus: onUpdateStatus,
              onPrint: () => onPrintTicket(order),
            ),
          );
        }, childCount: pageItems.length),
      );
    }

    // Modo Lista en Móviles
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final order = pageItems[index];
        final isSelected = isWide && selectedOrder?.id == order.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RepaintBoundary(
            child: AdminOrderCard(
              order: order,
              isProcessing:
                  cubit.state.isOrderProcessing(order.id) ||
                  state.isBackgroundLoading,
              isGeneratingPDF: state.isGeneratingPDF(order.id),
              isSelected: isSelected,
              isLoyaltyEnabled: isLoyaltyEnabled,
              onTap: () => onSelectOrder(order),
              onUpdateStatus: onUpdateStatus,
              onPrint: () => onPrintTicket(order),
            ),
          ),
        );
      }, childCount: pageItems.length),
    );
  }
}
