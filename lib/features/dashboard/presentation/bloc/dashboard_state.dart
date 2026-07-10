import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/enums/sales_time_filter.dart';

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
  final SalesTimeFilter salesFilter;
  final bool isSalesLoading;

  const DashboardLoaded({
    required this.inventory,
    required this.sales,
    required this.criticalBatches,
    required this.salesFilter,
    this.isSalesLoading = false,
  });

  DashboardLoaded copyWith({
    InventoryMetricsEntity? inventory,
    SalesMetricsEntity? sales,
    List<Map<String, dynamic>>? criticalBatches,
    SalesTimeFilter? salesFilter,
    bool? isSalesLoading,
  }) {
    return DashboardLoaded(
      inventory: inventory ?? this.inventory,
      sales: sales ?? this.sales,
      criticalBatches: criticalBatches ?? this.criticalBatches,
      salesFilter: salesFilter ?? this.salesFilter,
      isSalesLoading: isSalesLoading ?? this.isSalesLoading,
    );
  }

  @override
  List<Object?> get props => [
        inventory,
        sales,
        criticalBatches,
        salesFilter,
        isSalesLoading,
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}
