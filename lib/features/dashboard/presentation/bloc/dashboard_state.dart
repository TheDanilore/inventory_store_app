import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final InventoryMetricsEntity inventory;
  final SalesMetricsEntity sales;
  final List<Map<String, dynamic>> criticalBatches;
  final List<CustomerEntity> topCustomers;
  final SalesTimeFilter salesFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final bool isSalesLoading;

  const DashboardLoaded({
    required this.inventory,
    required this.sales,
    required this.criticalBatches,
    this.topCustomers = const [],
    required this.salesFilter,
    this.customStartDate,
    this.customEndDate,
    this.isSalesLoading = false,
  });

  DashboardLoaded copyWith({
    InventoryMetricsEntity? inventory,
    SalesMetricsEntity? sales,
    List<Map<String, dynamic>>? criticalBatches,
    List<CustomerEntity>? topCustomers,
    SalesTimeFilter? salesFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool? isSalesLoading,
  }) {
    return DashboardLoaded(
      inventory: inventory ?? this.inventory,
      sales: sales ?? this.sales,
      criticalBatches: criticalBatches ?? this.criticalBatches,
      topCustomers: topCustomers ?? this.topCustomers,
      salesFilter: salesFilter ?? this.salesFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      isSalesLoading: isSalesLoading ?? this.isSalesLoading,
    );
  }

  @override
  List<Object?> get props => [
    inventory,
    sales,
    criticalBatches,
    topCustomers,
    salesFilter,
    customStartDate,
    customEndDate,
    isSalesLoading,
  ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}
