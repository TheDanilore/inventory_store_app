import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

abstract class CustomersState extends Equatable {
  const CustomersState();

  @override
  List<Object?> get props => [];
}

class CustomersInitial extends CustomersState {}

class CustomersLoading extends CustomersState {}

class CustomersLoaded extends CustomersState {
  final List<CustomerEntity> customers;
  final bool hasReachedMax;
  final String query;
  final bool showOnlyWithDebt;
  final bool isRefreshing;

  const CustomersLoaded({
    required this.customers,
    required this.hasReachedMax,
    this.query = '',
    this.showOnlyWithDebt = false,
    this.isRefreshing = false,
  });

  bool get hasCustomers => customers.isNotEmpty;

  CustomersLoaded copyWith({
    List<CustomerEntity>? customers,
    bool? hasReachedMax,
    String? query,
    bool? showOnlyWithDebt,
    bool? isRefreshing,
  }) {
    return CustomersLoaded(
      customers: customers ?? this.customers,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      query: query ?? this.query,
      showOnlyWithDebt: showOnlyWithDebt ?? this.showOnlyWithDebt,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [
    customers,
    hasReachedMax,
    query,
    showOnlyWithDebt,
    isRefreshing,
  ];
}

class CustomersError extends CustomersState {
  final String message;

  const CustomersError(this.message);

  @override
  List<Object?> get props => [message];
}
