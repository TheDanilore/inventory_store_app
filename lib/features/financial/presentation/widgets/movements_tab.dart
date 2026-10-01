import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_state.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_state.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movement_form_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';

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

class _MovementsTabState extends State<MovementsTab> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

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

  void _showFiltersSheet(
    BuildContext context,
    AccountMovementsCubit movCubit,
    MovementFilters filters,
    List<FinancialAccountEntity> accounts,
  ) {
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
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
                          DropdownMenuItem(
                            value: 'INCOME',
                            child: Text('Ingresos'),
                          ),
                          DropdownMenuItem(
                            value: 'EXPENSE',
                            child: Text('Egresos'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            movCubit.setFilterType(v);
                            Navigator.pop(ctx);
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
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            movCubit.setFilterAccount(v);
                            Navigator.pop(ctx);
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
                      Navigator.pop(ctx);
                    },
                    onClear: () {
                      movCubit.setDateRange(null, null);
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
    return BlocBuilder<AccountMovementsCubit, AccountMovementsState>(
      builder: (context, movState) {
        final movCubit = context.read<AccountMovementsCubit>();

        // Mostrar error si hay uno
        if (movState is AccountMovementsError) {
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

        final movements =
            movState is AccountMovementsLoaded
                ? movState.movements
                : <AccountMovementEntity>[];
        final isLoading = movState is AccountMovementsLoading;
        final totalIncome =
            movState is AccountMovementsLoaded ? movState.totalIncome : 0.0;
        final totalExpense =
            movState is AccountMovementsLoaded ? movState.totalExpense : 0.0;
        final filters =
            movState is AccountMovementsLoaded
                ? movState.filters
                : const MovementFilters();

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
                _DashboardSummary(
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
                            () => _showFiltersSheet(
                              context,
                              movCubit,
                              filters,
                              accounts,
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
                            Icons.filter_list_rounded,
                            size: 14,
                            color: AppColors.tealDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Filtrando por: ${accounts.where((a) => a.id == filters.filterAccountId).firstOrNull?.name ?? "Cuenta seleccionada"}',
                              style: const TextStyle(
                                fontSize: 11.5,
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
                          ? const _MovementsSkeleton()
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
                                    final isDesktop = constraints.maxWidth >= 720;
                                    if (isDesktop) {
                                      return _MovementsDesktopTable(
                                        movements: movements,
                                        scrollController: _scrollController,
                                      );
                                    }
                                    return RefreshIndicator(
                                      onRefresh:
                                          () async => movCubit.fetchMovements(),
                                      child: AnimationLimiter(
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
                                              (_, i) =>
                                                  AnimationConfiguration.staggeredList(
                                                    position: i,
                                                    duration: const Duration(
                                                      milliseconds: 300,
                                                    ),
                                                    child: SlideAnimation(
                                                      verticalOffset: 30.0,
                                                      child: FadeInAnimation(
                                                        child: _MovementCard(
                                                          movement: movements[i],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
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
                            if (!kIsWeb) {
                              Vibration.vibrate(duration: 50, amplitude: 128);
                            }
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

class _DashboardSummary extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;

  const _DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    final balance = totalIncome - totalExpense;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DashItem(
                  title: 'Ingresos',
                  amount: totalIncome,
                  color: AppColors.tealDark,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _DashItem(
                  title: 'Egresos',
                  amount: totalExpense,
                  color: AppColors.danger,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _DashItem(
                  title: 'Flujo Neto',
                  amount: balance,
                  color: balance >= 0 ? AppColors.tealDark : AppColors.danger,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (totalIncome > 0 || totalExpense > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  if (totalIncome > 0)
                    Expanded(
                      flex: (totalIncome * 100).toInt(),
                      child: Container(height: 4, color: AppColors.teal),
                    ),
                  if (totalExpense > 0)
                    Expanded(
                      flex: (totalExpense * 100).toInt(),
                      child: Container(height: 4, color: AppColors.danger),
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

  const _DashItem({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'S/ ${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            color: color,
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MovementCard extends StatefulWidget {
  final AccountMovementEntity movement;

  const _MovementCard({required this.movement});

  @override
  State<_MovementCard> createState() => _MovementCardState();
}

class _MovementCardState extends State<_MovementCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final movement = widget.movement;
    final isIncome = movement.movementType == 'INCOME';
    final color = isIncome ? AppColors.tealDark : AppColors.danger;
    final icon =
        isIncome ? Icons.add_circle_rounded : Icons.remove_circle_rounded;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                _isHovered
                    ? AppColors.teal.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _isHovered ? 0.06 : 0.025,
              ),
              blurRadius: _isHovered ? 14 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      Flexible(
                        child: Text(
                          movement.accountName ?? 'Sin cuenta',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                          'es',
                        ).format(movement.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  movement.createdByName?.split(' ').first ?? 'Sistema',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
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

// ── Data Table Pro para Desktop y Tablets Horizontales ───────────────────────
class _MovementsDesktopTable extends StatelessWidget {
  final List<AccountMovementEntity> movements;
  final ScrollController scrollController;

  const _MovementsDesktopTable({
    required this.movements,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // Cabecera fija de la tabla
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      'FECHA Y HORA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'DESCRIPCIÓN / MOTIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Text(
                      'CUENTA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      'TIPO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      'REGISTRADO POR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      'MONTO (S/)',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filas
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: movements.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  return _DesktopMovementRow(movement: movements[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopMovementRow extends StatefulWidget {
  final AccountMovementEntity movement;
  const _DesktopMovementRow({required this.movement});

  @override
  State<_DesktopMovementRow> createState() => _DesktopMovementRowState();
}

class _DesktopMovementRowState extends State<_DesktopMovementRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.movement;
    final isIncome = m.movementType == 'INCOME';
    final isExpense = m.movementType == 'EXPENSE';

    final Color badgeBg = isIncome
        ? AppColors.teal.withValues(alpha: 0.1)
        : (isExpense
            ? AppColors.danger.withValues(alpha: 0.1)
            : AppColors.info.withValues(alpha: 0.1));
    final Color badgeColor = isIncome
        ? AppColors.tealDark
        : (isExpense ? AppColors.dangerDark : AppColors.info);
    final String badgeLabel = isIncome
        ? 'Ingreso'
        : (isExpense ? 'Egreso' : 'Transfer.');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Fecha y hora
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm', 'es').format(m.createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Descripción
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  m.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Cuenta
            SizedBox(
              width: 150,
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 13,
                    color: AppColors.tealDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.accountName ?? 'Sin cuenta',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Tipo badge
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ),
            ),
            // Operador
            SizedBox(
              width: 120,
              child: Text(
                m.createdByName?.split(' ').first ?? 'Sistema',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Monto
            SizedBox(
              width: 130,
              child: Text(
                '${isIncome ? '+' : '-'} S/ ${m.amount.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isIncome ? AppColors.tealDark : AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
