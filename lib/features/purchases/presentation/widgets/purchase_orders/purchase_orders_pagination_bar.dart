import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_view_model.dart';

/// Barra de paginación fluida para slivers de órdenes de compra.
class PurchaseOrdersPaginationBar extends StatelessWidget {
  final PurchaseOrdersViewModel viewModel;

  const PurchaseOrdersPaginationBar({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading || viewModel.orders.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 24));
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(opacity: 0.03),
          ),
          child: AdminPageBlocks(
            currentPage: viewModel.currentPage,
            totalPages: viewModel.totalPages,
            onPageChanged: (p) => viewModel.setPage(p),
            totalItems: viewModel.totalCount,
            itemsPerPage: viewModel.pageSize,
            availableItemsPerPage: const [10, 20, 24, 50, 100],
            onItemsPerPageChanged: (newSize) => viewModel.setPageSize(newSize),
            itemName: 'órdenes',
          ),
        ),
      ),
    );
  }
}
