import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';

abstract class CustomerDetailState extends Equatable {
  const CustomerDetailState();

  @override
  List<Object?> get props => [];
}

class CustomerDetailInitial extends CustomerDetailState {}

class CustomerDetailLoading extends CustomerDetailState {}

class CustomerDetailLoaded extends CustomerDetailState {
  final CustomerEntity customer;
  final List<RecentOrderEntity> recentOrders;
  final List<TopProductEntity> topProducts;

  const CustomerDetailLoaded({
    required this.customer,
    this.recentOrders = const [],
    this.topProducts = const [],
  });

  CustomerDetailLoaded copyWith({
    CustomerEntity? customer,
    List<RecentOrderEntity>? recentOrders,
    List<TopProductEntity>? topProducts,
  }) {
    return CustomerDetailLoaded(
      customer: customer ?? this.customer,
      recentOrders: recentOrders ?? this.recentOrders,
      topProducts: topProducts ?? this.topProducts,
    );
  }

  @override
  List<Object?> get props => [customer, recentOrders, topProducts];
}

class CustomerDetailError extends CustomerDetailState {
  final String message;

  const CustomerDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
