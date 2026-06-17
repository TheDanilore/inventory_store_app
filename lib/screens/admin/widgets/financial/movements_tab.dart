import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/account_movement_model.dart';
import 'package:inventory_store_app/providers/admin/account_movements_provider.dart';
import 'package:inventory_store_app/providers/admin/financial_accounts_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/movement_form_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class MovementsTab extends StatelessWidget {
  const MovementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccountMovementsProvider, FinancialAccountsProvider>(
      builder: (context, movProvider, accProvider, _) {
        final movements = movProvider.movements;
        final isLoading = movProvider.isLoading;
        final accounts = accProvider.accounts;

        return Stack(
          children: [
            Column(
              children: [
                _DashboardSummary(
                  totalIncome: movProvider.totalIncome,
                  totalExpense: movProvider.totalExpense,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: movProvider.filterType,
                              isExpanded: true,
                              icon: const Icon(Icons.filter_list_rounded, size: 18),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(value: 'Todos', child: Text('Todos los tipos')),
                                DropdownMenuItem(value: 'INCOME', child: Text('Ingresos')),
                                DropdownMenuItem(value: 'EXPENSE', child: Text('Egresos')),
                              ],
                              onChanged: (v) {
                                if (v != null) movProvider.setFilterType(v);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: movProvider.filterAccountId,
                              isExpanded: true,
                              icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              items: [
                                const DropdownMenuItem(value: 'Todas', child: Text('Todas las cuentas')),
                                ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                              ],
                              onChanged: (v) {
                                if (v != null) movProvider.setFilterAccount(v);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DateFilterCalendar(
                        dateRange: movProvider.dateFrom != null && movProvider.dateTo != null
                            ? DateTimeRange(start: movProvider.dateFrom!, end: movProvider.dateTo!)
                            : null,
                        onDateRangeSelected: (picked) {
                          movProvider.setDateRange(
                            picked.start,
                            DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                          );
                        },
                        onClear: () {
                          movProvider.setDateRange(null, null);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            onChanged: (val) => movProvider.setSearchText(val),
                            decoration: InputDecoration(
                              hintText: 'Buscar por descripción...',
                              hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Export Button
                      InkWell(
                        onTap: () {
                          // Implement Export to CSV here
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.download_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text('Exportar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: isLoading && movements.isEmpty
                      ? const _MovementsSkeleton()
                      : movements.isEmpty
                          ? const AppEmptyState(icon: Icons.sync_alt_rounded, title: 'Sin movimientos', message: 'No se encontraron movimientos financieros.')
                          : Column(
                              children: [
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh: () async => movProvider.fetchMovements(),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                      itemCount: movements.length,
                                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                                      itemBuilder: (_, i) => _MovementCard(movement: movements[i]),
                                    ),
                                  ),
                                ),
                                if (movProvider.totalPages > 1)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                                    child: AdminPageBlocks(
                                      currentPage: movProvider.currentPage,
                                      totalPages: movProvider.totalPages,
                                      onPageChanged: (page) => movProvider.setPage(page),
                                    ),
                                  ),
                                const SizedBox(height: 60), // Space for FAB
                              ],
                            ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_movements',
                onPressed: isLoading ? null : () => MovementFormSheet.show(context),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardSummary extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;

  const _DashboardSummary({required this.totalIncome, required this.totalExpense});

  @override
  Widget build(BuildContext context) {
    final balance = totalIncome - totalExpense;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DashItem(
                  title: 'Ingresos',
                  amount: totalIncome,
                  color: AppColors.success,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(
                child: _DashItem(
                  title: 'Egresos',
                  amount: totalExpense,
                  color: AppColors.danger,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(
                child: _DashItem(
                  title: 'Flujo Neto',
                  amount: balance,
                  color: balance >= 0 ? AppColors.primary : AppColors.danger,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Simple visual bar
          if (totalIncome > 0 || totalExpense > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  if (totalIncome > 0)
                    Expanded(
                      flex: (totalIncome * 100).toInt(),
                      child: Container(height: 6, color: AppColors.success),
                    ),
                  if (totalExpense > 0)
                    Expanded(
                      flex: (totalExpense * 100).toInt(),
                      child: Container(height: 6, color: AppColors.danger),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DashItem extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _DashItem({required this.title, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'S/ ${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  final AccountMovementModel movement;

  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isIncome = movement.movementType == 'INCOME';
    final color = isIncome ? AppColors.success : AppColors.danger;
    final icon = isIncome ? Icons.add_circle_rounded : Icons.remove_circle_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.description,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text(
                        movement.accountName ?? 'Sin cuenta',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM HH:mm').format(movement.createdAt),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'} S/ ${movement.amount.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  movement.createdByName.split(' ')[0],
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _MovementsSkeleton extends StatelessWidget {
  const _MovementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const AppShimmer(width: 40, height: 40, isCircular: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmer(width: 160, height: 16),
                    SizedBox(height: 8),
                    AppShimmer(width: 100, height: 12),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  AppShimmer(width: 60, height: 16),
                  SizedBox(height: 8),
                  AppShimmer(width: 40, height: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
