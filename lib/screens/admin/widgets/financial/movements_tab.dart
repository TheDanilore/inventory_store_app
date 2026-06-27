import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/account_movement_model.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/providers/admin/account_movements_provider.dart';
import 'package:inventory_store_app/providers/admin/financial_accounts_provider.dart';
import 'package:inventory_store_app/shared/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/movement_form_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key});

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended) {
        setState(() => _isFabExtended = false);
      } else if (_scrollController.offset <= 10 && !_isFabExtended) {
        setState(() => _isFabExtended = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showFiltersSheet(BuildContext context, AccountMovementsProvider movProvider, List<FinancialAccountModel> accounts) {
    // Solo vibrar si no es web para evitar MissingPluginException
    if (!kIsWeb) {
      Vibration.vibrate(duration: 50, amplitude: 128);
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  const Text('Tipo de Movimiento', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                        value: movProvider.filterType,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'Todos', child: Text('Todos los tipos')),
                          DropdownMenuItem(value: 'INCOME', child: Text('Ingresos')),
                          DropdownMenuItem(value: 'EXPENSE', child: Text('Egresos')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            movProvider.setFilterType(v);
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Cuenta Financiera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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
                        value: movProvider.filterAccountId,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.textSecondary),
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        items: [
                          const DropdownMenuItem(value: 'Todas', child: Text('Todas las cuentas')),
                          ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            movProvider.setFilterAccount(v);
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Rango de Fechas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DateFilterCalendar(
                    isExpanded: true,
                    dateRange: movProvider.dateFrom != null && movProvider.dateTo != null
                        ? DateTimeRange(start: movProvider.dateFrom!, end: movProvider.dateTo!)
                        : null,
                    onDateRangeSelected: (picked) {
                      movProvider.setDateRange(
                        picked.start,
                        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                      );
                      Navigator.pop(ctx);
                    },
                    onClear: () {
                      movProvider.setDateRange(null, null);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
                              )
                            ],
                          ),
                          child: TextField(
                            onChanged: (val) => movProvider.setSearchText(val),
                            decoration: InputDecoration(
                              hintText: 'Buscar movimientos...',
                              hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter Button
                      InkWell(
                        onTap: () => _showFiltersSheet(context, movProvider, accounts),
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
                              )
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.tune_rounded, size: 22, color: AppColors.textPrimary),
                              if (movProvider.filterType != 'Todos' || movProvider.filterAccountId != 'Todas' || movProvider.dateFrom != null)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  ),
                                ),
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
                                    child: AnimationLimiter(
                                      child: ListView.separated(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                        itemCount: movements.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                                        itemBuilder: (_, i) => AnimationConfiguration.staggeredList(
                                          position: i,
                                          duration: const Duration(milliseconds: 375),
                                          child: SlideAnimation(
                                            verticalOffset: 50.0,
                                            child: FadeInAnimation(
                                              child: _MovementCard(movement: movements[i]),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ],
                            ),
                ),
                // --- PAGINACIÓN ANCLADA ---
                if (movProvider.totalPages > 1 && !isLoading)
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
                        currentPage: movProvider.currentPage,
                        totalPages: movProvider.totalPages,
                        onPageChanged: (page) => movProvider.setPage(page),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_movements',
                onPressed: isLoading ? null : () {
                  // Solo vibrar si no es web para evitar MissingPluginException
                  if (!kIsWeb) {
                    Vibration.vibrate(duration: 50, amplitude: 128);
                  }
                  MovementFormSheet.show(context);
                },
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _isFabExtended 
                      ? const Text('Registrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                      : const SizedBox.shrink(),
                ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          )
        ],
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
                      Flexible(
                        child: Text(
                          movement.accountName ?? 'Sin cuenta',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
