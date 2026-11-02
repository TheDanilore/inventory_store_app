import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_state.dart';

/// Barra de paginación fluida al pie del scroll para la pantalla de pedidos.
class OrdersPaginationBar extends StatelessWidget {
  final OrdersState state;
  final OrdersCubit cubit;
  final ScrollController scrollController;

  const OrdersPaginationBar({
    super.key,
    required this.state,
    required this.cubit,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading ||
        state.errorMessage.isNotEmpty ||
        state.orders.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox(height: 24));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:
                isDark
                    ? AppColors.darkSurface
                    : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
            boxShadow:
                isDark
                    ? AppColors.darkCardShadow(opacity: 0.1)
                    : AppColors.cardShadow(opacity: 0.03),
          ),
          child: AdminPageBlocks(
            currentPage: state.currentPage,
            totalPages: state.totalPages,
            onPageChanged: (page) {
              cubit.goToPage(page);
              if (scrollController.hasClients) {
                scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            totalItems: state.totalRecords,
            itemsPerPage: state.pageSize,
            onItemsPerPageChanged: (size) => cubit.setPageSize(size),
            itemName: 'pedidos',
          ),
        ),
      ),
    );
  }
}
