import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

/// Resultado paginado del directorio de clientes con conteo total en servidor.
class CustomersPageEntity extends Equatable {
  final List<CustomerEntity> customers;
  final int totalCount;
  final bool hasMore;

  const CustomersPageEntity({
    required this.customers,
    required this.totalCount,
    required this.hasMore,
  });

  CustomersPageEntity copyWith({
    List<CustomerEntity>? customers,
    int? totalCount,
    bool? hasMore,
  }) {
    return CustomersPageEntity(
      customers: customers ?? this.customers,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [customers, totalCount, hasMore];
}
