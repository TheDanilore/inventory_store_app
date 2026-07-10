import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

abstract class TopCustomersState extends Equatable {
  const TopCustomersState();

  @override
  List<Object?> get props => [];
}

class TopCustomersInitial extends TopCustomersState {}

class TopCustomersLoading extends TopCustomersState {}

class TopCustomersLoaded extends TopCustomersState {
  final List<CustomerEntity> topCustomers;

  const TopCustomersLoaded(this.topCustomers);

  @override
  List<Object?> get props => [topCustomers];
}

class TopCustomersError extends TopCustomersState {
  final String message;

  const TopCustomersError(this.message);

  @override
  List<Object?> get props => [message];
}
