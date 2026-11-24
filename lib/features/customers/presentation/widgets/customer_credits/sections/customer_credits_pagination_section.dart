import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';

/// Paginación aislada con BlocSelector que permanece visible durante SWR
/// para evitar saltos de layout.
class CustomerCreditsPaginationSection extends StatelessWidget {
  final ScrollController scrollController;

  const CustomerCreditsPaginationSection({
    super.key,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CustomerCreditListCubit,
      CustomerCreditListState,
      ({int currentPage, int totalPages, int totalItems, bool isColdLoading})
    >(
      selector:
          (state) => (
            currentPage: state.currentPage,
            totalPages: state.totalPages,
            totalItems: state.totalAccounts,
            isColdLoading: state.isColdLoading,
          ),
      builder: (context, vm) {
        if (vm.isColdLoading || vm.totalItems == 0) {
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
                currentPage: vm.currentPage,
                totalPages: vm.totalPages,
                onPageChanged: (page) {
                  context.read<CustomerCreditListCubit>().setPage(page);
                  if (scrollController.hasClients) {
                    scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                totalItems: vm.totalItems,
                itemName: 'créditos de clientes',
              ),
            ),
          ),
        );
      },
    );
  }
}
