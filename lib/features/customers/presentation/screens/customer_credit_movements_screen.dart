import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_movements_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_movements_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credit_movements/date_divider.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credit_movements/movement_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credit_movements/movements_summary_header.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/order_detail_sheet.dart';

/// Pantalla de movimientos de crédito de un cliente.
///
/// **Importante:** Esta pantalla NO crea su propio [BlocProvider] para
/// [CustomerCreditMovementsCubit]. El provider es responsabilidad del route
/// en [customers_routes.dart], lo que permite que tanto el `body` como las
/// `actions` del [AdminLayout] compartan el mismo Cubit.
///
/// Parámetros:
/// - [creditId]: ID del crédito para cargar los movimientos.
/// - [customerName]: Nombre del cliente (informativo, no se recarga).
/// - [currentDebt]: Deuda actual (informativa, viene del contexto del crédito).
/// - [creditLimit]: Límite de crédito (informativo).
class CustomerCreditMovementsScreen extends StatefulWidget {
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
  State<CustomerCreditMovementsScreen> createState() =>
      _CustomerCreditMovementsScreenState();
}

class _CustomerCreditMovementsScreenState
    extends State<CustomerCreditMovementsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context
          .read<CustomerCreditMovementsCubit>()
          .loadMore(widget.creditId);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers de UI
  // ---------------------------------------------------------------------------

  /// Muestra el indicador de carga mientras se obtiene el detalle de la orden.
  void _showOrderLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  /// Abre el [OrderDetailSheet] con la orden cargada.
  Future<void> _showOrderDetail(
    BuildContext ctx,
    CustomerCreditMovementsOrderReady state,
  ) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => sl<OrderDetailCubit>()..fetchData(state.order.id),
        child: OrderDetailSheet(order: state.order),
      ),
    );
    // Consumir el estado de "orden lista" para evitar re-apertura accidental.
    if (mounted) {
      ctx.read<CustomerCreditMovementsCubit>().clearOrderPreview();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final debtPercent = widget.creditLimit > 0
        ? (widget.currentDebt / widget.creditLimit).clamp(0.0, 1.0)
        : 0.0;

    return BlocConsumer<CustomerCreditMovementsCubit,
        CustomerCreditMovementsState>(
      // Escuchar solo los sub-estados que requieren acciones de UI de una sola vez.
      listenWhen: (previous, current) =>
          current is CustomerCreditMovementsOrderLoading ||
          current is CustomerCreditMovementsOrderReady ||
          current is CustomerCreditMovementsOrderError,
      listener: (ctx, state) {
        if (state is CustomerCreditMovementsOrderLoading) {
          _showOrderLoadingDialog();
          return;
        }

        // Cerrar el diálogo de carga (si existiera abierto).
        if (Navigator.canPop(ctx)) Navigator.pop(ctx);

        if (state is CustomerCreditMovementsOrderReady) {
          _showOrderDetail(ctx, state);
          return;
        }

        if (state is CustomerCreditMovementsOrderError) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.orderErrorMessage),
              backgroundColor: AppColors.error,
            ),
          );
          ctx.read<CustomerCreditMovementsCubit>().clearOrderPreview();
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            // ----------------------------------------------------------------
            // Header de resumen del crédito
            // ----------------------------------------------------------------
            _buildSummaryHeader(state, debtPercent),
            const SizedBox(height: 24),

            // ----------------------------------------------------------------
            // Lista de movimientos
            // ----------------------------------------------------------------
            Expanded(child: _buildMovementsList(state)),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets privados
  // ---------------------------------------------------------------------------

  Widget _buildSummaryHeader(
    CustomerCreditMovementsState state,
    double debtPercent,
  ) {
    // Cuando los movimientos están cargados, usamos los getters computados.
    // Mientras carga (estado inicial/loading), mostramos ceros como placeholder.
    final totalCharged =
        state is CustomerCreditMovementsLoaded ? state.totalCharged : 0.0;
    final totalPaid =
        state is CustomerCreditMovementsLoaded ? state.totalPaid : 0.0;

    return MovementsSummaryHeader(
      customerName: widget.customerName,
      currentDebt: widget.currentDebt,
      creditLimit: widget.creditLimit,
      debtPercent: debtPercent,
      totalCharged: totalCharged,
      totalPaid: totalPaid,
    );
  }

  Widget _buildMovementsList(CustomerCreditMovementsState state) {
    if (state is CustomerCreditMovementsLoading ||
        state is CustomerCreditMovementsInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is CustomerCreditMovementsError) {
      return Center(
        child: Text(
          state.message,
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }

    if (state is CustomerCreditMovementsLoaded) {
      final movements = state.movements;

      if (movements.isEmpty) {
        return const Center(
          child: Text('No hay movimientos registrados'),
        );
      }

      // Construimos una lista plana que intercala DateDividers cuando el día
      // cambia entre un movimiento y el anterior.
      final items = _buildItemsWithDateDividers(state);

      return ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (state.hasReachedMax ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          // Indicador de carga de más elementos al final de la lista.
          if (index >= items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return items[index];
        },
      );
    }

    return const SizedBox.shrink();
  }

  /// Construye la lista de widgets intercalando [DateDivider] entre movimientos
  /// de días distintos. El primer movimiento siempre lleva su divider de fecha.
  List<Widget> _buildItemsWithDateDividers(
    CustomerCreditMovementsLoaded state,
  ) {
    final result = <Widget>[];
    DateTime? lastDate;

    for (final movement in state.movements) {
      final movDate = movement.createdAt?.toLocal();
      final movDay = movDate != null
          ? DateTime(movDate.year, movDate.month, movDate.day)
          : null;

      // Insertar divider si el día cambió (o es el primer elemento).
      final isDifferentDay = lastDate == null || movDay != lastDate;
      if (isDifferentDay) {
        result.add(DateDivider(date: movDate));
        lastDate = movDay;
      }

      result.add(
        MovementCard(
          movement: movement,
          // Delegamos la acción al Cubit, sin llamar UseCases desde la UI.
          onOpenOrder: (orderId) =>
              context.read<CustomerCreditMovementsCubit>().openOrderDetail(orderId),
        ),
      );
    }

    return result;
  }
}
