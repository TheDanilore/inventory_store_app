import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_overview.dart';
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

  /// Serie temporal + actividad por día de la semana (RPC). Null si aún no
  /// cargó o si falló: las tarjetas que lo usan se ocultan.
  final SalesOverview? overview;
  final List<Map<String, dynamic>> criticalBatches;
  final List<CustomerEntity> topCustomers;
  final SalesTimeFilter salesFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? selectedWarehouseId;
  final String? selectedWarehouseName;
  final bool isSalesLoading;
  final bool isBackgroundLoading;

  const DashboardLoaded({
    required this.inventory,
    required this.sales,
    this.overview,
    required this.criticalBatches,
    this.topCustomers = const [],
    required this.salesFilter,
    this.customStartDate,
    this.customEndDate,
    this.selectedWarehouseId,
    this.selectedWarehouseName,
    this.isSalesLoading = false,
    this.isBackgroundLoading = false,
  });

  DashboardLoaded copyWith({
    InventoryMetricsEntity? inventory,
    SalesMetricsEntity? sales,
    SalesOverview? overview,
    bool clearOverview = false,
    List<Map<String, dynamic>>? criticalBatches,
    List<CustomerEntity>? topCustomers,
    SalesTimeFilter? salesFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? selectedWarehouseId,
    String? selectedWarehouseName,
    bool clearWarehouse = false,
    bool? isSalesLoading,
    bool? isBackgroundLoading,
  }) {
    return DashboardLoaded(
      inventory: inventory ?? this.inventory,
      sales: sales ?? this.sales,
      overview: clearOverview ? null : (overview ?? this.overview),
      criticalBatches: criticalBatches ?? this.criticalBatches,
      topCustomers: topCustomers ?? this.topCustomers,
      salesFilter: salesFilter ?? this.salesFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      selectedWarehouseId:
          clearWarehouse
              ? null
              : (selectedWarehouseId ?? this.selectedWarehouseId),
      selectedWarehouseName:
          clearWarehouse
              ? null
              : (selectedWarehouseName ?? this.selectedWarehouseName),
      isSalesLoading: isSalesLoading ?? this.isSalesLoading,
      isBackgroundLoading: isBackgroundLoading ?? this.isBackgroundLoading,
    );
  }

  @override
  List<Object?> get props => [
    inventory,
    sales,
    overview,
    criticalBatches,
    topCustomers,
    salesFilter,
    customStartDate,
    customEndDate,
    selectedWarehouseId,
    selectedWarehouseName,
    isSalesLoading,
    isBackgroundLoading,
  ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object> get props => [message];
}
