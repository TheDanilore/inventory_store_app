import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/date_divider.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movement_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movements_summary_header.dart';

class CustomerCreditMovementsScreen extends StatelessWidget {
  final String creditId;
  final String customerName;
  final double currentDebt;
  final double creditLimit;

  const CustomerCreditMovementsScreen({
    super.key,
    required this.creditId,
    required this.customerName,
    this.currentDebt = 0.0,
    this.creditLimit = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerCreditMovementsCubit>()
        ..init(
          creditId: creditId,
          customerName: customerName,
          currentDebt: currentDebt,
          creditLimit: creditLimit,
        ),
      child: const _CustomerCreditMovementsScreenContent(),
    );
  }
}

class _CustomerCreditMovementsScreenContent extends StatelessWidget {
  const _CustomerCreditMovementsScreenContent();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerCreditMovementsCubit, CustomerCreditMovementsState>(
      listenWhen: (previous, current) =>
          previous.isExporting != current.isExporting ||
          previous.exportSuccess != current.exportSuccess ||
          previous.error != current.error,
      listener: (context, state) {
        if (state.exportSuccess && !state.isExporting) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF generado con éxito')),
          );
        } else if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red.shade700,
            ),
          );
        } else if (state.isExporting) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Generando PDF...')),
          );
        }
      },
      builder: (context, state) {
        return AdminLayout(
          title: 'Historial de Crédito',
          showBackButton: true,
          showDrawerButton: false, // Es una sub-pantalla
          settingsActions: const [
            PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
          ],
          onSettingsSelected: (value) {
            if (value == 'export' && !state.isExporting) {
              context.read<CustomerCreditMovementsCubit>().exportToPdf();
            }
          },
          body: state.isLoading && state.movements.isEmpty
              ? const _MovementsShimmer()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 700;

                    if (isTablet) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Panel Izquierdo: Resumen Fijo
                          SizedBox(
                            width: 350,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(top: 8),
                              child: MovementsSummaryHeader(
                                customerName: state.customerName,
                                currentDebt: state.currentDebt,
                                creditLimit: state.creditLimit,
                                debtPercent: state.debtPercent,
                                totalCharged: state.totalCharged,
                                totalPaid: state.totalPaid,
                              ),
                            ),
                          ),
                          // Panel Derecho: Lista de Movimientos Scrollable
                          Expanded(
                            child: _buildMainContent(
                              context,
                              state,
                              isTablet: true,
                            ),
                          ),
                        ],
                      );
                    }

                    // Mobile: Todo en un Scroll
                    return _buildMainContent(
                      context,
                      state,
                      isTablet: false,
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    CustomerCreditMovementsState state, {
    required bool isTablet,
  }) {
    final cubit = context.read<CustomerCreditMovementsCubit>();

    return Column(
      children: [
        if (state.isExporting) const LinearProgressIndicator(minHeight: 3),

        // Filtros Rápidos
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 20,
                color: Colors.grey,
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'Todo',
                isSelected: state.dateFilter == 'all',
                onSelected: () => cubit.setDateFilter('all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Este mes',
                isSelected: state.dateFilter == 'this_month',
                onSelected: () => cubit.setDateFilter('this_month'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Últimos 30 días',
                isSelected: state.dateFilter == '30_days',
                onSelected: () => cubit.setDateFilter('30_days'),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: cubit.loadData,
            color: Theme.of(context).colorScheme.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // En móvil, el header va dentro del scroll
                if (!isTablet)
                  SliverToBoxAdapter(
                    child: MovementsSummaryHeader(
                      customerName: state.customerName,
                      currentDebt: state.currentDebt,
                      creditLimit: state.creditLimit,
                      debtPercent: state.debtPercent,
                      totalCharged: state.totalCharged,
                      totalPaid: state.totalPaid,
                    ),
                  ),

                // Lista de movimientos
                if (state.movements.isEmpty && !state.isLoading)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.dateFilter != 'all'
                                  ? 'Sin movimientos en este periodo'
                                  : 'Esta cuenta aún no tiene movimientos',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (state.dateFilter != 'all')
                              TextButton.icon(
                                onPressed: () => cubit.setDateFilter('all'),
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Ver todo el historial'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final movement = state.movements[index];
                        final showDateLabel = index == 0 ||
                            !_sameDay(
                              movement.createdAt,
                              state.movements[index - 1].createdAt,
                            );

                        return TweenAnimationBuilder<double>(
                          duration: Duration(
                            milliseconds: 300 + (index * 40).clamp(0, 400),
                          ),
                          curve: Curves.easeOutCubic,
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showDateLabel) ...[
                                const SizedBox(height: 16),
                                DateDivider(date: movement.createdAt),
                                const SizedBox(height: 12),
                              ],
                              MovementCard(movement: movement),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      }, childCount: state.movements.length),
                    ),
                  ),

                  // Loading footer for pagination / refresh
                  if (state.isLoading && state.movements.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
              ],
            ),
          ),
        ),

        // Paginación fija al fondo
        if (state.totalPages > 1)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: AdminPageBlocks(
                currentPage: state.currentPage,
                totalPages: state.totalPages,
                onPageChanged: cubit.setPage,
              ),
            ),
          ),
      ],
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(label),
      backgroundColor:
          isSelected ? theme.colorScheme.primary : Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onSelected,
    );
  }
}

class _MovementsShimmer extends StatelessWidget {
  const _MovementsShimmer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;

        final headerShimmer = Container(
          margin: const EdgeInsets.all(16.0),
          child: const AppShimmer(height: 230, borderRadius: 20),
        );

        final listShimmer = ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          itemBuilder:
              (_, _) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppShimmer(height: 88, borderRadius: 16),
              ),
        );

        if (isTablet) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 350, child: headerShimmer),
              Expanded(child: listShimmer),
            ],
          );
        }

        return Column(children: [headerShimmer, Expanded(child: listShimmer)]);
      },
    );
  }
}
