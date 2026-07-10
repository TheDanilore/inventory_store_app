import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';

abstract class CustomerCreditsState extends Equatable {
  const CustomerCreditsState();

  @override
  List<Object?> get props => [];
}

class CustomerCreditsInitial extends CustomerCreditsState {}

class CustomerCreditsLoading extends CustomerCreditsState {}

class CustomerCreditsLoaded extends CustomerCreditsState {
  final CustomerCreditEntity creditAccount;
  final List<CreditMovementEntity> movements;
  final bool hasReachedMaxMovements;

  const CustomerCreditsLoaded({
    required this.creditAccount,
    required this.movements,
    required this.hasReachedMaxMovements,
  });

  CustomerCreditsLoaded copyWith({
    CustomerCreditEntity? creditAccount,
    List<CreditMovementEntity>? movements,
    bool? hasReachedMaxMovements,
  }) {
    return CustomerCreditsLoaded(
      creditAccount: creditAccount ?? this.creditAccount,
      movements: movements ?? this.movements,
      hasReachedMaxMovements: hasReachedMaxMovements ?? this.hasReachedMaxMovements,
    );
  }

  @override
  List<Object?> get props => [creditAccount, movements, hasReachedMaxMovements];
}

class CustomerCreditsError extends CustomerCreditsState {
  final String message;

  const CustomerCreditsError(this.message);

  @override
  List<Object?> get props => [message];
}
