import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';

class SupplierCreditsPaginationSection extends StatelessWidget {
  final ValueChanged<int> onPageChanged;

  const SupplierCreditsPaginationSection({
    super.key,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SupplierCreditsCubit,
      SupplierCreditsState,
      ({int currentPage, int totalPages, int totalCount, bool isColdLoading})
    >(
      selector:
          (state) => (
            currentPage: state.currentPage,
            totalPages: state.totalPages,
            totalCount: state.totalCount,
            isColdLoading: state.isColdLoading,
          ),
      builder: (context, vm) {
        if (vm.isColdLoading || vm.totalCount == 0) {
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
                onPageChanged: onPageChanged,
                totalItems: vm.totalCount,
                itemsPerPage: SupplierCreditsCubit.pageSize,
                itemName: 'líneas de crédito',
              ),
            ),
          ),
        );
      },
    );
  }
}
