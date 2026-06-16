import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/admin/customer_credit_movements_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:provider/provider.dart';
import 'widgets/customer_credit_movements/movements_summary_header.dart';
import 'widgets/customer_credit_movements/movement_card.dart';
import 'widgets/customer_credit_movements/date_divider.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

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
      settingsActions: const [
        PopupMenuItem(value: 'filter', child: Text('Filtrar por fecha')),
        PopupMenuItem(value: 'export', child: Text('Exportar a PDF')),
      ],
      onSettingsSelected: (value) {
        if (value == 'export') {
          if (!provider.isExporting) provider.exportToPdf();
        } else if (value == 'filter') {
          _showFilterSheet(context, provider);
        }
      },
      body:
          provider.isLoading
              ? const _MovementsShimmer()
              : Column(
                children: [
                  if (provider.isExporting)
                    const LinearProgressIndicator(minHeight: 3),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: provider.loadData,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Encabezado con resumen
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

                          // Etiqueta de Filtro activo
                          if (provider.dateFilter != 'all')
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Chip(
                                      label: Text(
                                        provider.dateFilter == '30_days'
                                            ? 'Últimos 30 días'
                                            : 'Este mes',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 14,
                                      ),
                                      onDeleted:
                                          () => provider.setDateFilter('all'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Lista de movimientos
                          if (provider.movements.isEmpty)
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
                                      'Sin movimientos en este periodo',
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
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final movement = provider.movements[index];
                                  final showDateLabel =
                                      index == 0 ||
                                      !_sameDay(
                                        movement.createdAt,
                                        provider.movements[index - 1].createdAt,
                                      );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (showDateLabel) ...[
                                        const SizedBox(height: 16),
                                        DateDivider(date: movement.createdAt),
                                        const SizedBox(height: 8),
                                      ],
                                      MovementCard(movement: movement),
                                      const SizedBox(height: 8),
                                    ],
                                  );
                                }, childCount: provider.movements.length),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Paginación
                  if (provider.totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: AdminPageBlocks(
                        currentPage: provider.currentPage,
                        totalPages: provider.totalPages,
                        onPageChanged: provider.setPage,
                      ),
                    ),
                ],
              ),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showFilterSheet(
    BuildContext context,
    CustomerCreditMovementsProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    'Filtrar por fecha',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: const Text('Últimos 30 días'),
                  trailing:
                      provider.dateFilter == '30_days'
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                  onTap: () {
                    provider.setDateFilter('30_days');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Este mes'),
                  trailing:
                      provider.dateFilter == 'this_month'
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                  onTap: () {
                    provider.setDateFilter('this_month');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text('Todos los movimientos'),
                  trailing:
                      provider.dateFilter == 'all'
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                  onTap: () {
                    provider.setDateFilter('all');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MovementsShimmer extends StatelessWidget {
  const _MovementsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: AppShimmer(height: 180, borderRadius: 20),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder:
                (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppShimmer(height: 80, borderRadius: 14),
                ),
          ),
        ),
      ],
    );
  }
}
