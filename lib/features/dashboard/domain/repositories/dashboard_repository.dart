import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/enums/sales_time_filter.dart';

abstract class DashboardRepository {
  Future<Either<Failure, InventoryMetricsEntity>> getInventoryMetrics();
  Future<Either<Failure, SalesMetricsEntity>> getSalesMetrics({
    required SalesTimeFilter filter,
  });
  Future<Either<Failure, List<Map<String, dynamic>>>> getCriticalBatches({
    int daysThreshold = 30,
  });
}
