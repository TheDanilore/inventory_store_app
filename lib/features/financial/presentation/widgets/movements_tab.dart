import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_state.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_state.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movement_form_sheet.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movements/movements_card.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movements/movements_dashboard_summary.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movements/movements_desktop_table.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movements/movements_filter_sheet.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movements/movements_skeleton.dart';

class MovementsTab extends StatefulWidget {
  final bool showFab;
  final VoidCallback? onClearAccountFilter;
  final FocusNode? searchFocusNode;

  const MovementsTab({
    super.key,
    this.showFab = true,
    this.onClearAccountFilter,
    this.searchFocusNode,
  });

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 10 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    });
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<AccountMovementsCubit, AccountMovementsState>(
      builder: (context, movState) {
        final movCubit = context.read<AccountMovementsCubit>();

        final movements = switch (movState) {
          AccountMovementsLoaded(:final movements) => movements,
          AccountMovementsLoading(:final previousMovements) =>
            previousMovements,
          AccountMovementSaving(:final previousMovements) => previousMovements,
          AccountMovementSaved(:final previousMovements) => previousMovements,
          AccountMovementsError(:final previousMovements) => previousMovements,
          _ => <AccountMovementEntity>[],
        };

        // Mostrar error si no hay datos en memoria para soportar Frame-0
        if (movState is AccountMovementsError && movements.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.danger,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    movState.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => movCubit.fetchMovements(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final isLoading = movState is AccountMovementsLoading;
        final totalIncome = switch (movState) {
          AccountMovementsLoaded(:final totalIncome) => totalIncome,
          AccountMovementsLoading(:final totalIncome) => totalIncome,
          AccountMovementSaving(:final totalIncome) => totalIncome,
          _ => 0.0,
        };
        final totalExpense = switch (movState) {
          AccountMovementsLoaded(:final totalExpense) => totalExpense,
          AccountMovementsLoading(:final totalExpense) => totalExpense,
          AccountMovementSaving(:final totalExpense) => totalExpense,
          _ => 0.0,
        };
        final filters = switch (movState) {
          AccountMovementsLoaded(:final filters) => filters,
          AccountMovementsLoading(:final filters) =>
            filters ?? const MovementFilters(),
          _ => movCubit.filters,
        };

        final accounts = context
            .select<FinancialAccountsCubit, List<FinancialAccountEntity>>(
              (cubit) =>
                  cubit.state is FinancialAccountsLoaded
                      ? (cubit.state as FinancialAccountsLoaded).accounts
                      : <FinancialAccountEntity>[],
            );

        return Stack(
          children: [
            Column(
              children: [
                MovementsDashboardSummary(
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.transparent),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            focusNode: widget.searchFocusNode,
                            onChanged: (val) => movCubit.setSearchText(val),
                            decoration: InputDecoration(
                              hintText: 'Buscar movimientos... [/]',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter Button
                      InkWell(
                        onTap:
                            () => MovementsFilterSheet.show(
                              context: context,
                              movCubit: movCubit,
                              filters: filters,
                              accounts: accounts,
                            ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.transparent),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                size: 22,
                                color: AppColors.textPrimary,
                              ),
                              if (filters.filterType != 'Todos' ||
                                  filters.filterAccountId != 'Todas' ||
                                  filters.dateFrom != null)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (filters.filterAccountId != 'Todas')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.teal.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_alt_outlined,
                            size: 14,
                            color: AppColors.tealDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Filtrando por: ${accounts.where((a) => a.id == filters.filterAccountId).firstOrNull?.name ?? filters.filterAccountId}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tealDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              movCubit.setFilterAccount('Todas');
                              widget.onClearAccountFilter?.call();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Quitar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.tealDark,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: AppColors.tealDark,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child:
                      isLoading && movements.isEmpty
                          ? const MovementsSkeleton()
                          : movements.isEmpty
                          ? const AppEmptyState(
                            icon: Icons.sync_alt_rounded,
                            title: 'Sin movimientos',
                            message:
                                'No se encontraron movimientos financieros.',
                          )
                          : Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isDesktop =
                                        constraints.maxWidth >= 720;
                                    if (isDesktop) {
                                      return MovementsDesktopTable(
                                        movements: movements,
                                        scrollController: _scrollController,
                                      );
                                    }
                                    return RefreshIndicator(
                                      onRefresh:
                                          () async => movCubit.fetchMovements(),
                                      child: ListView.separated(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          4,
                                          16,
                                          16,
                                        ),
                                        itemCount: movements.length,
                                        separatorBuilder:
                                            (_, _) => const SizedBox(height: 8),
                                        itemBuilder:
                                            (_, i) => MovementsCard(
                                              movement: movements[i],
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                ),
                // --- PAGINACIÓN ANCLADA ---
                if (movState is AccountMovementsLoaded &&
                    movState.totalPages > 1 &&
                    !isLoading)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: AdminPageBlocks(
                        currentPage: movState.currentPage,
                        totalPages: movState.totalPages,
                        onPageChanged: (page) => movCubit.setPage(page),
                      ),
                    ),
                  ),
              ],
            ),
            if (widget.showFab)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_movements',
                  onPressed:
                      isLoading
                          ? null
                          : () {
                            AppFeedbackService.mediumImpact();
                            MovementFormSheet.show(context);
                          },
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: ValueListenableBuilder<bool>(
                    valueListenable: _isFabExtended,
                    builder: (context, isExtended, _) {
                      return AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child:
                            isExtended
                                ? const Text(
                                  'Registrar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                                : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
