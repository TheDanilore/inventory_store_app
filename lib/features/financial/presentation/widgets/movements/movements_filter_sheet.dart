import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_cubit.dart';

class MovementsFilterSheet extends StatelessWidget {
  final AccountMovementsCubit movCubit;
  final MovementFilters filters;
  final List<FinancialAccountEntity> accounts;

  const MovementsFilterSheet({
    super.key,
    required this.movCubit,
    required this.filters,
    required this.accounts,
  });

  static Future<void> show({
    required BuildContext context,
    required AccountMovementsCubit movCubit,
    required MovementFilters filters,
    required List<FinancialAccountEntity> accounts,
  }) {
    AppFeedbackService.mediumImpact();
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => MovementsFilterSheet(
            movCubit: movCubit,
            filters: filters,
            accounts: accounts,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Filtros',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tipo de Movimiento',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filters.filterType,
                isExpanded: true,
                icon: const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Todos',
                    child: Text('Todos los tipos'),
                  ),
                  DropdownMenuItem(value: 'INCOME', child: Text('Ingresos')),
                  DropdownMenuItem(value: 'EXPENSE', child: Text('Egresos')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    movCubit.setFilterType(v);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cuenta Financiera',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filters.filterAccountId,
                isExpanded: true,
                icon: const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'Todas',
                    child: Text('Todas las cuentas'),
                  ),
                  ...accounts.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    movCubit.setFilterAccount(v);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rango de Fechas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DateFilterCalendar(
            isExpanded: true,
            dateRange:
                filters.dateFrom != null && filters.dateTo != null
                    ? DateTimeRange(
                      start: filters.dateFrom!,
                      end: filters.dateTo!,
                    )
                    : null,
            onDateRangeSelected: (picked) {
              movCubit.setDateRange(
                picked.start,
                DateTime(
                  picked.end.year,
                  picked.end.month,
                  picked.end.day,
                  23,
                  59,
                  59,
                ),
              );
              Navigator.pop(context);
            },
            onClear: () {
              movCubit.setDateRange(null, null);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
