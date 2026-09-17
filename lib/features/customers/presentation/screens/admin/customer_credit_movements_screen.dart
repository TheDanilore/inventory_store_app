import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/date_divider.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movement_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/credit_movements/movements_summary_header.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credit_payment_modal.dart';
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
  String _typeFilter = 'ALL'; // 'ALL', 'PAYMENT', 'CHARGE'

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

    CustomerCreditPaymentModal.show(
      context,
      account: creditEntity,
      onSaved: () => cubit.loadData(),
      onSavePayment: (amount, accountId, orderId, notes) async {
        await sl<RegisterCreditPaymentUseCase>()(
          customerId: widget.customerId,
          creditId: widget.creditId,
          amount: amount,
          accountId: accountId,
          orderId: orderId,
          notes: notes,
        );
      },
    );
  }

  void _exportToPdf() {
    context.read<CustomerCreditMovementsCubit>().exportToPdf();
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

  List<CreditMovementEntity> _filterMovements(
    List<CreditMovementEntity> movements,
  ) {
    if (_typeFilter == 'PAYMENT') {
      return movements.where((m) => m.movementType == 'PAYMENT').toList();
    }
    if (_typeFilter == 'CHARGE') {
      return movements.where((m) => m.movementType == 'CHARGE').toList();
    }
    return movements;
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
        child:
            BlocConsumer<
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
                } else if (state.isExporting) {
                  AppSnackbar.show(
                    context,
                    message: 'Generando PDF de movimientos...',
                    type: SnackbarType.info,
                  );
                }
              },
              builder: (context, state) {
                return AdminLayout(
                  title: 'Historial de Crédito',
                  showBackButton: true,
                  showDrawerButton: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refrescar datos',
                      onPressed: () {
                        context
                            .read<CustomerCreditMovementsCubit>()
                            .loadData();
                      },
                    ),
                    IconButton(
                      icon:
                          state.isExporting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                              : const Icon(Icons.picture_as_pdf_rounded),
                      tooltip: 'Exportar PDF [Alt + E]',
                      onPressed: state.isExporting ? null : _exportToPdf,
                    ),
                  ],
                  body: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 1050;
                      final isTablet =
                          constraints.maxWidth >= 700 &&
                          constraints.maxWidth < 1050;

                      if (isDesktop) {
                        return _buildDesktopLayout(context, state);
                      }

                      if (isTablet) {
                        return _buildTabletLayout(context, state);
                      }

                      return _buildMobileLayout(context, state);
                    },
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
  ) {
    final filtered = _filterMovements(state.movements);
    final cubit = context.read<CustomerCreditMovementsCubit>();

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
                // Resumen Financiero con Gradiente Slate
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
                        onPressed: state.isExporting ? null : _exportToPdf,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon:
                            state.isExporting
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(
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
              if (state.isExporting)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: AppColors.primary,
                ),

              // Toolbar Unificada de Filtros
              _buildProToolbar(
                context,
                state: state,
                cubit: cubit,
                isDesktop: true,
              ),

              // Contenedor Principal: Data Table o Estados
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.loadData,
                  color: AppColors.primary,
                  child:
                      state.isLoading && state.movements.isEmpty
                          ? const _DesktopLedgerSkeleton()
                          : filtered.isEmpty
                          ? Center(
                            child: AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'Sin movimientos registrados',
                              message:
                                  state.dateFilter != 'all' ||
                                          _typeFilter != 'ALL'
                                      ? 'No se encontraron movimientos para los filtros seleccionados.'
                                      : 'Esta cuenta aún no presenta cargos ni abonos.',
                              action:
                                  state.dateFilter != 'all' ||
                                          _typeFilter != 'ALL'
                                      ? FilledButton.tonal(
                                        onPressed: () {
                                          setState(() => _typeFilter = 'ALL');
                                          cubit.setDateFilter('all');
                                        },
                                        child: const Text('Restablecer filtros'),
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
                            child: _MovementsLedgerDataTable(
                              movements: filtered,
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
  ) {
    final filtered = _filterMovements(state.movements);
    final cubit = context.read<CustomerCreditMovementsCubit>();

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
              _buildProToolbar(
                context,
                state: state,
                cubit: cubit,
                isDesktop: false,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.loadData,
                  color: AppColors.primary,
                  child:
                      filtered.isEmpty
                          ? Center(
                            child: AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'Sin movimientos',
                              message: 'No hay movimientos en este periodo.',
                              action: FilledButton(
                                onPressed: () {
                                  setState(() => _typeFilter = 'ALL');
                                  cubit.setDateFilter('all');
                                },
                                child: const Text('Ver todos'),
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final movement = filtered[index];
                              final showDateLabel =
                                  index == 0 ||
                                  !_sameDay(
                                    movement.createdAt,
                                    filtered[index - 1].createdAt,
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
  ) {
    final filtered = _filterMovements(state.movements);
    final cubit = context.read<CustomerCreditMovementsCubit>();

    return Column(
      children: [
        if (state.isExporting)
          const LinearProgressIndicator(
            minHeight: 3,
            color: AppColors.primary,
          ),

        // Filtros táctiles en scroll horizontal
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TypePill(
                  label: 'Todos',
                  count: state.movements.length,
                  isSelected: _typeFilter == 'ALL',
                  onTap: () => setState(() => _typeFilter = 'ALL'),
                ),
                const SizedBox(width: 8),
                _TypePill(
                  label: 'Abonos (-)',
                  count:
                      state.movements
                          .where((m) => m.movementType == 'PAYMENT')
                          .length,
                  isSelected: _typeFilter == 'PAYMENT',
                  color: const Color(0xFF16A34A),
                  onTap: () => setState(() => _typeFilter = 'PAYMENT'),
                ),
                const SizedBox(width: 8),
                _TypePill(
                  label: 'Cargos (+)',
                  count:
                      state.movements
                          .where((m) => m.movementType == 'CHARGE')
                          .length,
                  isSelected: _typeFilter == 'CHARGE',
                  color: const Color(0xFFEA580C),
                  onTap: () => setState(() => _typeFilter = 'CHARGE'),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: AppColors.border),
                const SizedBox(width: 12),
                _DateFilterChip(
                  label: 'Todo',
                  isSelected: state.dateFilter == 'all',
                  onTap: () => cubit.setDateFilter('all'),
                ),
                const SizedBox(width: 6),
                _DateFilterChip(
                  label: 'Este mes',
                  isSelected: state.dateFilter == 'this_month',
                  onTap: () => cubit.setDateFilter('this_month'),
                ),
                const SizedBox(width: 6),
                _DateFilterChip(
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
            onRefresh: cubit.loadData,
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
                              onPressed:
                                  state.isExporting ? null : _exportToPdf,
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
                if (filtered.isEmpty && !state.isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sin movimientos',
                        message: 'No hay registros en este periodo.',
                        action: FilledButton(
                          onPressed: () {
                            setState(() => _typeFilter = 'ALL');
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
                        final movement = filtered[index];
                        final showDateLabel =
                            index == 0 ||
                            !_sameDay(
                              movement.createdAt,
                              filtered[index - 1].createdAt,
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
                      }, childCount: filtered.length),
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

  // ---------------------------------------------------------------------------
  // SHARED: TOOLBAR UNIFICADA (Desktop / Tablet)
  // ---------------------------------------------------------------------------
  Widget _buildProToolbar(
    BuildContext context, {
    required CustomerCreditMovementsState state,
    required CustomerCreditMovementsCubit cubit,
    required bool isDesktop,
  }) {
    final paymentsCount =
        state.movements.where((m) => m.movementType == 'PAYMENT').length;
    final chargesCount =
        state.movements.where((m) => m.movementType == 'CHARGE').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Type Pills
          _TypePill(
            label: 'Todos',
            count: state.movements.length,
            isSelected: _typeFilter == 'ALL',
            onTap: () => setState(() => _typeFilter = 'ALL'),
          ),
          const SizedBox(width: 8),
          _TypePill(
            label: 'Abonos (-)',
            count: paymentsCount,
            isSelected: _typeFilter == 'PAYMENT',
            color: const Color(0xFF16A34A),
            onTap: () => setState(() => _typeFilter = 'PAYMENT'),
          ),
          const SizedBox(width: 8),
          _TypePill(
            label: 'Cargos (+)',
            count: chargesCount,
            isSelected: _typeFilter == 'CHARGE',
            color: const Color(0xFFEA580C),
            onTap: () => setState(() => _typeFilter = 'CHARGE'),
          ),

          const Spacer(),

          // Date Filter Pills
          _DateFilterChip(
            label: 'Todo',
            isSelected: state.dateFilter == 'all',
            onTap: () => cubit.setDateFilter('all'),
          ),
          const SizedBox(width: 6),
          _DateFilterChip(
            label: 'Este mes',
            isSelected: state.dateFilter == 'this_month',
            onTap: () => cubit.setDateFilter('this_month'),
          ),
          const SizedBox(width: 6),
          _DateFilterChip(
            label: 'Últimos 30 días',
            isSelected: state.dateFilter == '30_days',
            onTap: () => cubit.setDateFilter('30_days'),
          ),
        ],
      ),
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

// -----------------------------------------------------------------------------
// Component: Segmented Type Pill
// -----------------------------------------------------------------------------
class _TypePill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.count,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Component: Date Filter Chip
// -----------------------------------------------------------------------------
class _DateFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Component: High-Density Ledger Data Table (Stripe Style)
// -----------------------------------------------------------------------------
class _MovementsLedgerDataTable extends StatelessWidget {
  final List<CreditMovementEntity> movements;
  final void Function(String orderId) onOpenOrder;
  final void Function(String text, String label) onCopy;

  const _MovementsLedgerDataTable({
    required this.movements,
    required this.onOpenOrder,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'FECHA Y HORA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'CONCEPTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'REFERENCIA / PEDIDO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MEDIO / CUENTA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RESPONSABLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'MONTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'VER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: movements.length,
            separatorBuilder:
                (_, _) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final movement = movements[index];
              return _DesktopLedgerRow(
                movement: movement,
                onOpenOrder: onOpenOrder,
                onCopy: onCopy,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DesktopLedgerRow extends StatefulWidget {
  final CreditMovementEntity movement;
  final void Function(String orderId) onOpenOrder;
  final void Function(String text, String label) onCopy;

  const _DesktopLedgerRow({
    required this.movement,
    required this.onOpenOrder,
    required this.onCopy,
  });

  @override
  State<_DesktopLedgerRow> createState() => _DesktopLedgerRowState();
}

class _DesktopLedgerRowState extends State<_DesktopLedgerRow> {
  bool _isHovered = false;

  void _showContextMenu(TapDownDetails details) {
    final m = widget.movement;
    final position = RelativeRect.fromRect(
      details.globalPosition & const Size(40, 40),
      Offset.zero & MediaQuery.of(context).size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 6,
      items: [
        if (m.orderId != null)
          PopupMenuItem(
            value: 'order',
            child: Row(
              children: const [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 10),
                Text('Ver detalle del pedido'),
              ],
            ),
          ),
        if (m.orderNumber != null)
          PopupMenuItem(
            value: 'copy_order',
            child: Row(
              children: const [
                Icon(Icons.copy_rounded, size: 18, color: AppColors.textMuted),
                SizedBox(width: 10),
                Text('Copiar número de pedido'),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'copy_amount',
          child: Row(
            children: const [
              Icon(
                Icons.attach_money_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 10),
              Text('Copiar monto'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'order':
          if (m.orderId != null) widget.onOpenOrder(m.orderId!);
          break;
        case 'copy_order':
          if (m.orderNumber != null) {
            widget.onCopy(m.orderNumber!, 'Nº de Pedido');
          }
          break;
        case 'copy_amount':
          widget.onCopy(m.amount.toStringAsFixed(2), 'Monto');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movement;
    final isCharge = m.movementType == 'CHARGE';
    final sign = isCharge ? '+' : '-';
    final amountColor =
        isCharge ? const Color(0xFFEA580C) : const Color(0xFF16A34A);

    final dateStr =
        m.createdAt != null
            ? DateFormat('d MMM yyyy', 'es').format(m.createdAt!.toLocal())
            : '--';
    final timeStr =
        m.createdAt != null
            ? DateFormat.jm().format(m.createdAt!.toLocal())
            : '--:--';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: _showContextMenu,
        onTap: m.orderId != null ? () => widget.onOpenOrder(m.orderId!) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          child: Row(
            children: [
              // 1. Fecha y Hora
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Concepto / Tipo Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isCharge
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isCharge
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCharge
                              ? Icons.shopping_cart_rounded
                              : Icons.payments_rounded,
                          size: 13,
                          color: amountColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isCharge ? 'Cargo por venta' : 'Abono registrado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Referencia / Pedido
              Expanded(
                flex: 2,
                child:
                    m.orderNumber != null
                        ? InkWell(
                          onTap:
                              m.orderId != null
                                  ? () => widget.onOpenOrder(m.orderId!)
                                  : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  '#${m.orderNumber!.length > 10 ? m.orderNumber!.substring(0, 8) : m.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 12,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        )
                        : Text(
                          m.notes != null && m.notes!.isNotEmpty
                              ? m.notes!
                              : '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
              ),

              // 4. Medio / Cuenta
              Expanded(
                flex: 2,
                child: Text(
                  m.orderPaymentMethod ?? m.paymentMethod ?? 'Caja / General',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 5. Responsable
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m.createdByName ?? 'Desconocido',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 6. Monto
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$sign S/ ${m.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: amountColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              // 7. Acciones
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      m.orderId != null
                          ? IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 17,
                            ),
                            tooltip: 'Ver pedido asociado',
                            splashRadius: 16,
                            color: AppColors.textSecondary,
                            onPressed: () => widget.onOpenOrder(m.orderId!),
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Component: Desktop Ledger Skeleton
// -----------------------------------------------------------------------------
class _DesktopLedgerSkeleton extends StatelessWidget {
  const _DesktopLedgerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 90, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 80, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: AppShimmer(width: 70, height: 12, borderRadius: 4),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 60, height: 12, borderRadius: 4),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppShimmer(width: 24, height: 12, borderRadius: 4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          for (int i = 0; i < 6; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: const [
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 90, height: 16, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 80, height: 20, borderRadius: 6),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 70, height: 16, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 75, height: 14, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: AppShimmer(width: 80, height: 14, borderRadius: 4),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 65, height: 16, borderRadius: 4),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AppShimmer(width: 20, height: 20, borderRadius: 4),
                    ),
                  ),
                ],
              ),
            ),
            if (i < 5) const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}
