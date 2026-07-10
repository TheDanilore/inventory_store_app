import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_ucs.dart';

abstract class CustomerCreditMovementsState {}

class CustomerCreditMovementsInitial extends CustomerCreditMovementsState {}

class CustomerCreditMovementsLoading extends CustomerCreditMovementsState {}

class CustomerCreditMovementsLoaded extends CustomerCreditMovementsState {
  final List<CreditMovementEntity> movements;
  final bool hasReachedMax;

  CustomerCreditMovementsLoaded({
    required this.movements,
    this.hasReachedMax = false,
  });

  CustomerCreditMovementsLoaded copyWith({
    List<CreditMovementEntity>? movements,
    bool? hasReachedMax,
  }) {
    return CustomerCreditMovementsLoaded(
      movements: movements ?? this.movements,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }
}

class CustomerCreditMovementsError extends CustomerCreditMovementsState {
  final String message;
  CustomerCreditMovementsError(this.message);
}

@injectable
class CustomerCreditMovementsCubit extends Cubit<CustomerCreditMovementsState> {
  final GetCreditMovementsUseCase _getCreditMovementsUseCase;
  static const int _limit = 20;

  CustomerCreditMovementsCubit(this._getCreditMovementsUseCase)
      : super(CustomerCreditMovementsInitial());

  Future<void> loadMovements(String creditId) async {
    emit(CustomerCreditMovementsLoading());
    try {
      final movements = await _getCreditMovementsUseCase(
        creditId: creditId,
        limit: _limit,
        offset: 0,
      );
      emit(CustomerCreditMovementsLoaded(
        movements: movements,
        hasReachedMax: movements.length < _limit,
      ));
    } catch (e) {
      emit(CustomerCreditMovementsError(e.toString()));
    }
  }

  Future<void> loadMore(String creditId) async {
    if (state is CustomerCreditMovementsLoaded) {
      final currentState = state as CustomerCreditMovementsLoaded;
      if (currentState.hasReachedMax) return;

      try {
        final newMovements = await _getCreditMovementsUseCase(
          creditId: creditId,
          limit: _limit,
          offset: currentState.movements.length,
        );
        emit(currentState.copyWith(
          movements: [...currentState.movements, ...newMovements],
          hasReachedMax: newMovements.length < _limit,
        ));
      } catch (e) {
        // Ignorar o manejar el error silenciosamente
      }
    }
  }
}
