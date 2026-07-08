import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customer_credit_movements_provider.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/admin_layout.dart';
import 'package:provider/provider.dart';
import 'widgets/customer_credit_movements/movements_summary_header.dart';
import 'widgets/customer_credit_movements/movement_card.dart';
import 'widgets/customer_credit_movements/date_divider.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

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
    return ChangeNotifierProvider(
      create:
          (_) =>
              CustomerCreditMovementsProvider()..init(
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
    final provider = context.watch<CustomerCreditMovementsProvider>();
    final debtPercent =
        provider.creditLimit > 0
            ? (provider.currentDebt / provider.creditLimit).clamp(0.0, 1.0)
            : 0.0;

    return AdminLayout(
      title: 'Historial de Crédito',
      showBackButton: true,
      settingsActions: [
        const PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
      ],
      onSettingsSelected: (value) {
        if (value == 'export' && !provider.isExporting) {
          provider.exportToPdf();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Generando PDF...')));
        }
      },
      body:
          provider.isLoading
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
                              customerName: provider.customerName,
                              currentDebt: provider.currentDebt,
                              creditLimit: provider.creditLimit,
                              debtPercent: debtPercent,
                              totalCharged: provider.totalCharged,
                              totalPaid: provider.totalPaid,
                            ),
                          ),
                        ),
                        // Panel Derecho: Lista de Movimientos Scrollable
                        Expanded(
                          child: _buildMainContent(
                            context,
                            provider,
                            isTablet: true,
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile: Todo en un Scroll
                  return _buildMainContent(
                    context,
                    provider,
                    isTablet: false,
                    debtPercent: debtPercent,
                  );
                },
              ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    CustomerCreditMovementsProvider provider, {
    required bool isTablet,
    double? debtPercent,
  }) {
    return Column(
      children: [
        if (provider.isExporting) const LinearProgressIndicator(minHeight: 3),

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
                isSelected: provider.dateFilter == 'all',
                onSelected: () => provider.setDateFilter('all'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Este mes',
                isSelected: provider.dateFilter == 'this_month',
                onSelected: () => provider.setDateFilter('this_month'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Últimos 30 días',
                isSelected: provider.dateFilter == '30_days',
                onSelected: () => provider.setDateFilter('30_days'),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: provider.loadData,
            color: Theme.of(context).colorScheme.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // En móvil, el header va dentro del scroll
                if (!isTablet && debtPercent != null)
                  SliverToBoxAdapter(
                    child: MovementsSummaryHeader(
                      customerName: provider.customerName,
                      currentDebt: provider.currentDebt,
                      creditLimit: provider.creditLimit,
                      debtPercent: debtPercent,
                      totalCharged: provider.totalCharged,
                      totalPaid: provider.totalPaid,
                    ),
                  ),

                // Lista de movimientos
                if (provider.movements.isEmpty)
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
                              provider.dateFilter != 'all'
                                  ? 'Sin movimientos en este periodo'
                                  : 'Esta cuenta aún no tiene movimientos',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (provider.dateFilter != 'all')
                              TextButton.icon(
                                onPressed: () => provider.setDateFilter('all'),
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
                        final movement = provider.movements[index];
                        final showDateLabel =
                            index == 0 ||
                            !_sameDay(
                              movement.createdAt,
                              provider.movements[index - 1].createdAt,
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
                      }, childCount: provider.movements.length),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Paginación fija al fondo (nunca se oculta por el scroll)
        if (provider.totalPages > 1)
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
                currentPage: provider.currentPage,
                totalPages: provider.totalPages,
                onPageChanged: provider.setPage,
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
