import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/global_stats_bar.dart';

/// Sección KPI aislada con BlocSelector para evitar reconstruir toda la pantalla.
class CustomerCreditsKpiSection extends StatelessWidget {
  const CustomerCreditsKpiSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CustomerCreditListCubit,
      CustomerCreditListState,
      ({
        bool isColdLoading,
        double totalDebt,
        int activeAccounts,
        int suspendedAccounts,
        int maxedOutAccounts,
        int debtCount,
      })
    >(
      selector:
          (state) => (
            isColdLoading: state.isColdLoading,
            totalDebt: state.totalDebt,
            activeAccounts: state.activeAccounts,
            suspendedAccounts: state.suspendedAccounts,
            maxedOutAccounts: state.maxedOutAccounts,
            debtCount: state.debtCount,
          ),
      builder: (context, vm) {
        if (vm.isColdLoading) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: GlobalStatsBar(
            totalDebt: vm.totalDebt,
            activeAccounts: vm.activeAccounts,
            suspendedAccounts: vm.suspendedAccounts,
            maxedOutAccounts: vm.maxedOutAccounts,
            accountsWithDebt: vm.debtCount,
          ),
        );
      },
    );
  }
}
