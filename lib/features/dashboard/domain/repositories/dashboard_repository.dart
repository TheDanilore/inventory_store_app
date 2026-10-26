import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_overview.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';

abstract class DashboardRepository {
  Future<Either<Failure, InventoryMetricsEntity>> getInventoryMetrics({
    bool forceRefresh = false,
    String? warehouseId,
  });
  Future<Either<Failure, SalesMetricsEntity>> getSalesMetrics({
    required SalesTimeFilter filter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool forceRefresh = false,
    String? warehouseId,
  });

  /// Serie temporal real + actividad semanal para el rango (from/to null = histórico).
  Future<Either<Failure, SalesOverview>> getSalesOverview({
    required DateTime? from,
    required DateTime? to,
    String? warehouseId,
  });
  Future<Either<Failure, List<Map<String, dynamic>>>> getCriticalBatches({
    int daysThreshold = 30,
    int limit = 15,
    bool forceRefresh = false,
    String? warehouseId,
  });
}
