import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/account_statement_export_sheet.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/date_divider.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movement_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movements_filter_toolbar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movements_ledger_data_table.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movements_ledger_skeleton.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movements_summary_header.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credit_payment_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail/order_detail_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_detail_sheet.dart';

class CustomerCreditMovementsScreen extends StatelessWidget {
  final String creditId;
  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final String customerId;

  const CustomerCreditMovementsScreen({
    super.key,
    required this.creditId,
    required this.customerName,
    this.currentDebt = 0.0,
    this.creditLimit = 0.0,
    this.customerId = '',
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (_) =>
              sl<CustomerCreditMovementsCubit>()..init(
                creditId: creditId,
                customerName: customerName,
                currentDebt: currentDebt,
                creditLimit: creditLimit,
                customerId: customerId,
              ),
      child: _CustomerCreditMovementsScreenContent(
        creditId: creditId,
        customerName: customerName,
        currentDebt: currentDebt,
        creditLimit: creditLimit,
        customerId: customerId,
      ),
    );
  }
}

class _CustomerCreditMovementsScreenContent extends StatefulWidget {
  final String creditId;
  final String customerName;
  final double currentDebt;
  final double creditLimit;
  final String customerId;

  const _CustomerCreditMovementsScreenContent({
    required this.creditId,
    required this.customerName,
    required this.currentDebt,
    required this.creditLimit,
    required this.customerId,
  });

  @override
  State<_CustomerCreditMovementsScreenContent> createState() =>
      _CustomerCreditMovementsScreenContentState();
}

class _CustomerCreditMovementsScreenContentState
    extends State<_CustomerCreditMovementsScreenContent> {
  void _openPaymentModal() {
    final cubit = context.read<CustomerCreditMovementsCubit>();
    final creditEntity = CustomerCreditEntity(
      id: widget.creditId,
      profileId: widget.customerId,
      customerName: widget.customerName,
      currentDebt: cubit.state.currentDebt,
      creditLimit: cubit.state.creditLimit,
      isActive: true,
    );

    CustomerCreditPaymentSheet.show(
      context,
      account: creditEntity,
      onSaved: () => cubit.loadData(forceRefresh: true),
      onSavePayment: (amount, accountId, orderId, notes, shiftId) async {
        await cubit.registerPayment(
          amount: amount,
          accountId: accountId,
          orderId: orderId,
          notes: notes,
          shiftId: shiftId,
        );
      },
    );
  }

  void _exportToPdf() {
    final state = context.read<CustomerCreditMovementsCubit>().state;
    AccountStatementExportSheet.show(
      context,
      titularName: widget.customerName,
      isSupplier: false,
      currentBalance: state.currentDebt,
      totalCharged: state.totalCharged,
      totalPaid: state.totalPaid,
      items: state.movements.map((m) => StatementItem.fromCustomer(m)).toList(),
    );
  }

  void _openOrderDetails(String orderId) async {
    final result = await sl<OrdersRepository>().getOrderById(orderId);
    if (!mounted) return;

    result.fold(
      (failure) {
        AppSnackbar.show(
          context,
          message: 'No se pudo cargar el pedido.',
          type: SnackbarType.error,
        );
      },
      (order) {
        final isWide = MediaQuery.of(context).size.width >= 700;
        if (isWide) {
          showDialog(
            context: context,
            builder:
                (ctx) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 580,
                      maxHeight: 700,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BlocProvider(
                        create:
                            (_) => sl<OrderDetailCubit>()..fetchData(order.id),
                        child: OrderDetailSheet(order: order),
                      ),
                    ),
                  ),
                ),
          );
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            builder:
                (ctx) => BlocProvider(
                  create: (_) => sl<OrderDetailCubit>()..fetchData(order.id),
                  child: OrderDetailSheet(order: order),
                ),
          );
        }
      },
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, alt: true):
            _openPaymentModal,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _openPaymentModal,
        const SingleActivator(LogicalKeyboardKey.keyE, alt: true): _exportToPdf,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true):
            _exportToPdf,
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
            _exportToPdf,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: BlocConsumer<
          CustomerCreditMovementsCubit,
          CustomerCreditMovementsState
        >(
          listenWhen:
              (previous, current) =>
                  previous.isExporting != current.isExporting ||
                  previous.exportSuccess != current.exportSuccess ||
                  previous.error != current.error,
          listener: (context, state) {
            if (state.exportSuccess && !state.isExporting) {
              AppSnackbar.show(
                context,
                message: 'Estado de cuenta en PDF generado con éxito',
                type: SnackbarType.success,
              );
            } else if (state.error != null) {
              AppSnackbar.show(
                context,
                message: state.error!,
                type: SnackbarType.error,
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<CustomerCreditMovementsCubit>();

            return AdminLayout(
              title: 'Historial de Crédito',
              showBackButton: true,
              showDrawerButton: false,
              actions: [
                IconButton(
                  icon:
                      state.isRevalidating
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                          : const Icon(Icons.refresh_rounded),
                  tooltip: 'Refrescar datos',
                  onPressed:
                      state.isRevalidating
                          ? null
                          : () => cubit.loadData(forceRefresh: true),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: 'Exportar PDF [Alt + E]',
                  onPressed: _exportToPdf,
                ),
              ],
              body: Column(
                children: [
                  // SWR: Barra de sincronización discreta de 2px en background (cero shimmer)
                  if (state.isRevalidating)
                    const LinearProgressIndicator(
                      minHeight: 2.5,
                      color: AppColors.primary,
                      backgroundColor: Colors.transparent,
                    ),

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 1050;
                        final isTablet =
                            constraints.maxWidth >= 700 &&
                            constraints.maxWidth < 1050;

                        if (isDesktop) {
                          return _buildDesktopLayout(context, state, cubit);
                        }

                        if (isTablet) {
                          return _buildTabletLayout(context, state, cubit);
                        }

                        return _buildMobileLayout(context, state, cubit);
                      },
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

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT (>= 1050px)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(
    BuildContext context,
    CustomerCreditMovementsState state,
    CustomerCreditMovementsCubit cubit,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel Izquierdo: Active Financial Sidebar (360px)
        SizedBox(
          width: 360,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MovementsSummaryHeader(
                  customerName: state.customerName,
                  currentDebt: state.currentDebt,
                  creditLimit: state.creditLimit,
                  debtPercent: state.debtPercent,
                  totalCharged: state.totalCharged,
                  totalPaid: state.totalPaid,
                ),
                const SizedBox(height: 14),

                // Centro de Acciones Rápidas
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ACCIONES RÁPIDAS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _openPaymentModal,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 18),
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Registrar Abono',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '[Alt + A]',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _exportToPdf,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Exportar Estado de Cuenta',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              '[Alt + E]',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Panel Derecho: Toolbar + Data Table
        Expanded(
          child: Column(
            children: [
              MovementsFilterToolbar(
                typeFilter: state.typeFilter,
                dateFilter: state.dateFilter,
                totalCount: state.totalCount,
                chargeCount: state.chargeCount,
                paymentCount: state.paymentCount,
                onTypeFilterChanged: cubit.setTypeFilter,
                onDateFilterChanged: cubit.setDateFilter,
              ),

              // Contenedor Principal: Data Table o Estados
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => cubit.loadData(forceRefresh: true),
                  color: AppColors.primary,
                  child:
                      // STALE-WHILE-REVALIDATE: Solo muestra esqueleto si no hay absolutamente ningún dato previo
                      state.isLoading && state.movements.isEmpty
                          ? const DesktopLedgerSkeleton()
                          : state.movements.isEmpty
                          ? Center(
                            child: AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'Sin movimientos registrados',
                              message:
                                  state.dateFilter != 'all' ||
                                          state.typeFilter != 'ALL'
                                      ? 'No se encontraron movimientos para los filtros seleccionados.'
                                      : 'Esta cuenta aún no presenta cargos ni abonos.',
                              action:
                                  state.dateFilter != 'all' ||
                                          state.typeFilter != 'ALL'
                                      ? FilledButton.tonal(
                                        onPressed: () {
                                          cubit.setTypeFilter('ALL');
                                          cubit.setDateFilter('all');
                                        },
                                        child: const Text(
                                          'Restablecer filtros',
                                        ),
                                      )
                                      : FilledButton.icon(
                                        onPressed: _openPaymentModal,
                                        icon: const Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Registrar Abono'),
                                      ),
                            ),
                          )
                          : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 4, 16, 16),
                            child: MovementsLedgerDataTable(
                              movements: state.movements,
                              onOpenOrder: _openOrderDetails,
                              onCopy: _copyToClipboard,
                            ),
                          ),
                ),
              ),

              // Paginación Inferior
              if (state.totalPages > 1)
                _buildPaginationBar(cubit: cubit, state: state),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TABLET LAYOUT (700px - 1049px)
  // ---------------------------------------------------------------------------
  Widget _buildTabletLayout(
    BuildContext context,
    CustomerCreditMovementsState state,
    CustomerCreditMovementsCubit cubit,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel Izquierdo Compacto
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 20),
            child: Column(
              children: [
                MovementsSummaryHeader(
                  customerName: state.customerName,
                  currentDebt: state.currentDebt,
                  creditLimit: state.creditLimit,
                  debtPercent: state.debtPercent,
                  totalCharged: state.totalCharged,
                  totalPaid: state.totalPaid,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _openPaymentModal,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text(
                    'Registrar Abono',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Panel Derecho: Lista Scrollable
        Expanded(
          child: Column(
            children: [
              MovementsFilterToolbar(
                typeFilter: state.typeFilter,
                dateFilter: state.dateFilter,
                totalCount: state.totalCount,
                chargeCount: state.chargeCount,
                paymentCount: state.paymentCount,
                onTypeFilterChanged: cubit.setTypeFilter,
                onDateFilterChanged: cubit.setDateFilter,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => cubit.loadData(forceRefresh: true),
                  color: AppColors.primary,
                  child:
                      state.isLoading && state.movements.isEmpty
                          ? const DesktopLedgerSkeleton()
                          : state.movements.isEmpty
                          ? Center(
                            child: AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'Sin movimientos',
                              message: 'No hay movimientos en este periodo.',
                              action: FilledButton(
                                onPressed: () {
                                  cubit.setTypeFilter('ALL');
                                  cubit.setDateFilter('all');
                                },
                                child: const Text('Ver todos'),
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
                            itemCount: state.movements.length,
                            itemBuilder: (context, index) {
                              final movement = state.movements[index];
                              final showDateLabel =
                                  index == 0 ||
                                  !_sameDay(
                                    movement.createdAt,
                                    state.movements[index - 1].createdAt,
                                  );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showDateLabel) ...[
                                    const SizedBox(height: 14),
                                    DateDivider(date: movement.createdAt),
                                    const SizedBox(height: 10),
                                  ],
                                  MovementCard(movement: movement),
                                  const SizedBox(height: 10),
                                ],
                              );
                            },
                          ),
                ),
              ),
              if (state.totalPages > 1)
                _buildPaginationBar(cubit: cubit, state: state),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (< 700px)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(
    BuildContext context,
    CustomerCreditMovementsState state,
    CustomerCreditMovementsCubit cubit,
  ) {
    return Column(
      children: [
        // Filtros táctiles en scroll horizontal
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TypePill(
                  label: 'Todos',
                  count:
                      (state.chargeCount + state.paymentCount) > 0
                          ? (state.chargeCount + state.paymentCount)
                          : state.totalCount,
                  isSelected: state.typeFilter == 'ALL',
                  onTap: () => cubit.setTypeFilter('ALL'),
                ),
                const SizedBox(width: 8),
                TypePill(
                  label: 'Abonos (-)',
                  count: state.paymentCount,
                  isSelected: state.typeFilter == 'PAYMENT',
                  color: const Color(0xFF16A34A),
                  onTap: () => cubit.setTypeFilter('PAYMENT'),
                ),
                const SizedBox(width: 8),
                TypePill(
                  label: 'Cargos (+)',
                  count: state.chargeCount,
                  isSelected: state.typeFilter == 'CHARGE',
                  color: const Color(0xFFEA580C),
                  onTap: () => cubit.setTypeFilter('CHARGE'),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: AppColors.border),
                const SizedBox(width: 12),
                DateFilterChip(
                  label: 'Todo',
                  isSelected: state.dateFilter == 'all',
                  onTap: () => cubit.setDateFilter('all'),
                ),
                const SizedBox(width: 6),
                DateFilterChip(
                  label: 'Este mes',
                  isSelected: state.dateFilter == 'this_month',
                  onTap: () => cubit.setDateFilter('this_month'),
                ),
                const SizedBox(width: 6),
                DateFilterChip(
                  label: '30 días',
                  isSelected: state.dateFilter == '30_days',
                  onTap: () => cubit.setDateFilter('30_days'),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.loadData(forceRefresh: true),
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header dentro del scroll en móvil
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        MovementsSummaryHeader(
                          customerName: state.customerName,
                          currentDebt: state.currentDebt,
                          creditLimit: state.creditLimit,
                          debtPercent: state.debtPercent,
                          totalCharged: state.totalCharged,
                          totalPaid: state.totalPaid,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _openPaymentModal,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.payments_rounded,
                                  size: 17,
                                ),
                                label: const Text(
                                  'Abonar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              onPressed: _exportToPdf,
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 18,
                              ),
                              tooltip: 'Exportar PDF',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Lista de movimientos
                if (state.movements.isEmpty && !state.isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sin movimientos',
                        message: 'No hay registros en este periodo.',
                        action: FilledButton(
                          onPressed: () {
                            cubit.setTypeFilter('ALL');
                            cubit.setDateFilter('all');
                          },
                          child: const Text('Ver todos'),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final movement = state.movements[index];
                        final showDateLabel =
                            index == 0 ||
                            !_sameDay(
                              movement.createdAt,
                              state.movements[index - 1].createdAt,
                            );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateLabel) ...[
                              const SizedBox(height: 14),
                              DateDivider(date: movement.createdAt),
                              const SizedBox(height: 10),
                            ],
                            MovementCard(movement: movement),
                            const SizedBox(height: 10),
                          ],
                        );
                      }, childCount: state.movements.length),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (state.totalPages > 1)
          _buildPaginationBar(cubit: cubit, state: state),
      ],
    );
  }

  Widget _buildPaginationBar({
    required CustomerCreditMovementsCubit cubit,
    required CustomerCreditMovementsState state,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: AdminPageBlocks(
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          onPageChanged: cubit.setPage,
        ),
      ),
    );
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
