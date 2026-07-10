import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';

abstract class CustomerCreditMovementsState extends Equatable {
  const CustomerCreditMovementsState();

  @override
  List<Object?> get props => [];
}

class CustomerCreditMovementsInitial extends CustomerCreditMovementsState {}

class CustomerCreditMovementsLoading extends CustomerCreditMovementsState {}

class CustomerCreditMovementsLoaded extends CustomerCreditMovementsState {
  final List<CreditMovementEntity> movements;
  final bool hasReachedMax;

  const CustomerCreditMovementsLoaded({
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

  @override
  List<Object?> get props => [movements, hasReachedMax];
}

class CustomerCreditMovementsError extends CustomerCreditMovementsState {
  final String message;

  const CustomerCreditMovementsError(this.message);

  @override
  List<Object?> get props => [message];
}
