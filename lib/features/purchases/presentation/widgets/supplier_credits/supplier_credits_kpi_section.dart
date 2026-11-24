import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_global_stats_bar.dart';

class SupplierCreditsKpiSection extends StatelessWidget {
  const SupplierCreditsKpiSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SupplierCreditsCubit,
      SupplierCreditsState,
      SupplierCreditStatsEntity
    >(
      selector: (state) => state.stats,
      builder: (context, stats) {
        return SupplierGlobalStatsBar(
          totalDebt: stats.totalDebt,
          activeAccounts: stats.activeAccounts,
          suspendedAccounts: stats.suspendedAccounts,
          maxedOutAccounts: stats.maxedOutAccounts,
        );
      },
    );
  }
}
