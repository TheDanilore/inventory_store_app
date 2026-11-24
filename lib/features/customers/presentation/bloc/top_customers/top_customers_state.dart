import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

sealed class TopCustomersState extends Equatable {
  const TopCustomersState();

  @override
  List<Object?> get props => [];
}

class TopCustomersInitial extends TopCustomersState {}

class TopCustomersLoading extends TopCustomersState {}

class TopCustomersLoaded extends TopCustomersState {
  final List<CustomerEntity> topCustomers;
  final bool isRefreshing;
  final String? transientErrorMessage;

  const TopCustomersLoaded(
    this.topCustomers, {
    this.isRefreshing = false,
    this.transientErrorMessage,
  });

  TopCustomersLoaded copyWith({
    List<CustomerEntity>? topCustomers,
    bool? isRefreshing,
    String? transientErrorMessage,
    bool clearTransientError = false,
  }) {
    return TopCustomersLoaded(
      topCustomers ?? this.topCustomers,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      transientErrorMessage:
          clearTransientError
              ? null
              : (transientErrorMessage ?? this.transientErrorMessage),
    );
  }

  @override
  List<Object?> get props => [topCustomers, isRefreshing, transientErrorMessage];
}

class TopCustomersError extends TopCustomersState {
  final String message;

  const TopCustomersError(this.message);

  @override
  List<Object?> get props => [message];
}
