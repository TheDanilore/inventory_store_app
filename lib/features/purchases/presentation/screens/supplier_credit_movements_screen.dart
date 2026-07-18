import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credit_movements/supplier_credit_movements_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credit_movements/supplier_credit_movements_state.dart';

// Widgets extraídos
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credit_movements/summary_header.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credit_movements/movement_card.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credit_movements_repository.dart';

class SupplierCreditMovementsScreen extends StatefulWidget {
  final String creditId;
  final String supplierName;
  final double currentDebt;
  final double creditLimit;

  const SupplierCreditMovementsScreen({
    super.key,
    required this.creditId,
    required this.supplierName,
    this.currentDebt = 0.0,
    this.creditLimit = 0.0,
  });

  @override
  State<SupplierCreditMovementsScreen> createState() =>
      _SupplierCreditMovementsScreenState();
}

class _SupplierCreditMovementsScreenState
    extends State<SupplierCreditMovementsScreen> {
  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showFilterSheet(
    BuildContext context,
    MovementDateFilter currentFilter,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Filtrar por fecha',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Este mes'),
                trailing:
                    currentFilter == MovementDateFilter.thisMonth
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                onTap: () {
                  context.read<SupplierCreditMovementsCubit>().setDateFilter(
                    MovementDateFilter.thisMonth,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Mes pasado'),
                trailing:
                    currentFilter == MovementDateFilter.lastMonth
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                onTap: () {
                  context.read<SupplierCreditMovementsCubit>().setDateFilter(
                    MovementDateFilter.lastMonth,
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('Todo el historial'),
                trailing:
                    currentFilter == MovementDateFilter.allTime
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                onTap: () {
                  context.read<SupplierCreditMovementsCubit>().setDateFilter(
                    MovementDateFilter.allTime,
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<
      SupplierCreditMovementsCubit,
      SupplierCreditMovementsState
    >(
      listener: (context, state) {
        if (state is SupplierCreditMovementsError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
          context.read<SupplierCreditMovementsCubit>().clearError();
        }
      },
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Inherited from AdminLayout in app_router
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: AppColors.textPrimary),
          title: const Text(
            'Historial de Cuenta',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            BlocBuilder<
              SupplierCreditMovementsCubit,
              SupplierCreditMovementsState
            >(
              builder: (context, state) {
                final isExporting =
                    state is SupplierCreditMovementsLoading &&
                    state
                        .currentMovements
                        .isNotEmpty; // Roughly indicates working if not initial load
                final currentFilter =
                    state is SupplierCreditMovementsLoaded
                        ? state.dateFilter
                        : (state is SupplierCreditMovementsLoading
                            ? state.dateFilter
                            : MovementDateFilter.thisMonth);

                if (isExporting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                return PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textPrimary,
                  ),
                  onSelected: (value) {
                    if (value == 'export') {
                      context
                          .read<SupplierCreditMovementsCubit>()
                          .exportToPdf();
                    } else if (value == 'filter') {
                      _showFilterSheet(context, currentFilter);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'export',
                          child: Text('Exportar a PDF'),
                        ),
                        const PopupMenuItem(
                          value: 'filter',
                          child: Text('Filtrar por fecha'),
                        ),
                      ],
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<
          SupplierCreditMovementsCubit,
          SupplierCreditMovementsState
        >(
          builder: (context, state) {
            final debtPercent =
                widget.creditLimit > 0
                    ? (widget.currentDebt / widget.creditLimit).clamp(0.0, 1.0)
                    : 0.0;

            final isLoading =
                state is SupplierCreditMovementsLoading ||
                state is SupplierCreditMovementsInitial;

            List<SupplierCreditMovementEntity> movements = [];
            double totalCharged = 0.0;
            double totalPaid = 0.0;
            int currentPage = 0;
            int totalPages = 1;

            if (state is SupplierCreditMovementsLoaded) {
              movements = state.movements;
              totalCharged = state.totalCharged;
              totalPaid = state.totalPaid;
              currentPage = state.currentPage;
              totalPages = state.totalPages;
            } else if (state is SupplierCreditMovementsLoading) {
              movements = state.currentMovements;
              totalCharged = state.totalCharged;
              totalPaid = state.totalPaid;
              currentPage = state.currentPage;
              totalPages =
                  state.totalCount == 0 ? 1 : (state.totalCount / 10).ceil();
            } else if (state is SupplierCreditMovementsError) {
              movements = state.currentMovements;
              totalCharged = state.totalCharged;
              totalPaid = state.totalPaid;
              currentPage = state.currentPage;
              totalPages =
                  state.totalCount == 0 ? 1 : (state.totalCount / 10).ceil();
            }

            return RefreshIndicator(
              onRefresh:
                  () => context
                      .read<SupplierCreditMovementsCubit>()
                      .loadMovements(refresh: true),
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: SupplierCreditMovementsSummaryHeader(
                            supplierName: widget.supplierName,
                            currentDebt: widget.currentDebt,
                            creditLimit: widget.creditLimit,
                            debtPercent: debtPercent,
                            totalCharged: totalCharged,
                            totalPaid: totalPaid,
                          ),
                        ),

                        if (isLoading && movements.isEmpty)
                          const SliverFillRemaining(child: _MovementsSkeleton())
                        else if (movements.isEmpty)
                          const SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 56,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Sin movimientos registrados',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final movement = movements[index];
                                final showDateLabel =
                                    index == 0 ||
                                    !_sameDay(
                                      movement.createdAt,
                                      movements[index - 1].createdAt,
                                    );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showDateLabel) ...[
                                      const SizedBox(height: 16),
                                      _DateDivider(date: movement.createdAt),
                                      const SizedBox(height: 8),
                                    ],
                                    SupplierCreditMovementCard(
                                      movement: movement,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              }, childCount: movements.length),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: AdminPageBlocks(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        onPageChanged:
                            context
                                .read<SupplierCreditMovementsCubit>()
                                .setPage,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime? date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == null) {
      label = 'Fecha desconocida';
    } else {
      final d = DateTime(date!.year, date!.month, date!.day);
      if (d == today) {
        label = 'Hoy';
      } else if (d == yesterday) {
        label = 'Ayer';
      } else {
        label = DateFormat('d MMMM yyyy', 'es').format(date!);
      }
    }

    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _MovementsSkeleton extends StatelessWidget {
  const _MovementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
