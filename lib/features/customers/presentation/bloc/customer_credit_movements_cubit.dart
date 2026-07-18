import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_ucs.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_movements_state.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_order_by_id_usecase.dart';

@injectable
class CustomerCreditMovementsCubit extends Cubit<CustomerCreditMovementsState> {
  final GetCreditMovementsUseCase _getCreditMovementsUseCase;
  final GetOrderByIdUseCase _getOrderByIdUseCase;

  static const int _limit = 20;

  CustomerCreditMovementsCubit(
    this._getCreditMovementsUseCase,
    this._getOrderByIdUseCase,
  ) : super(CustomerCreditMovementsInitial());

  // ---------------------------------------------------------------------------
  // Carga de movimientos (paginada)
  // ---------------------------------------------------------------------------

  Future<void> loadMovements(String creditId) async {
    emit(CustomerCreditMovementsLoading());
    try {
      final movements = await _getCreditMovementsUseCase(
        creditId: creditId,
        limit: _limit,
        offset: 0,
      );
      emit(
        CustomerCreditMovementsLoaded(
          movements: movements,
          hasReachedMax: movements.length < _limit,
        ),
      );
    } catch (e) {
      emit(CustomerCreditMovementsError(e.toString()));
    }
  }

  Future<void> loadMore(String creditId) async {
    if (state is! CustomerCreditMovementsLoaded) return;
    final currentState = state as CustomerCreditMovementsLoaded;
    if (currentState.hasReachedMax) return;

    try {
      final newMovements = await _getCreditMovementsUseCase(
        creditId: creditId,
        limit: _limit,
        offset: currentState.movements.length,
      );
      emit(
        currentState.copyWith(
          movements: [...currentState.movements, ...newMovements],
          hasReachedMax: newMovements.length < _limit,
        ),
      );
    } catch (_) {
      // Ignorar error de paginación silenciosamente; la lista existente permanece.
    }
  }

  // ---------------------------------------------------------------------------
  // Detalle de orden (apertura de OrderDetailSheet desde MovementCard)
  // ---------------------------------------------------------------------------

  /// Carga el detalle de la orden con [orderId] y emite [CustomerCreditMovementsOrderReady].
  /// La UI debe reaccionar con [BlocListener] para abrir el sheet y luego
  /// llamar a [clearOrderPreview] para "consumir" el evento.
  Future<void> openOrderDetail(String orderId) async {
    if (state is! CustomerCreditMovementsLoaded) return;
    final currentState = state as CustomerCreditMovementsLoaded;

    emit(
      CustomerCreditMovementsOrderLoading(
        movements: currentState.movements,
        hasReachedMax: currentState.hasReachedMax,
      ),
    );

    final result = await _getOrderByIdUseCase(orderId);
    result.fold(
      (failure) => emit(
        CustomerCreditMovementsOrderError(
          movements: currentState.movements,
          hasReachedMax: currentState.hasReachedMax,
          orderErrorMessage: failure.message,
        ),
      ),
      (order) => emit(
        CustomerCreditMovementsOrderReady(
          movements: currentState.movements,
          hasReachedMax: currentState.hasReachedMax,
          order: order,
        ),
      ),
    );
  }

  /// Regresa al estado [CustomerCreditMovementsLoaded] base después de que la
  /// UI ya mostró el sheet (o el error). Esto "consume" el evento de orden.
  void clearOrderPreview() {
    if (state is CustomerCreditMovementsLoaded) {
      final current = state as CustomerCreditMovementsLoaded;
      emit(
        CustomerCreditMovementsLoaded(
          movements: current.movements,
          hasReachedMax: current.hasReachedMax,
        ),
      );
    }
  }
}
