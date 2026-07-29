import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/domain/repositories/dashboard_repository.dart';

@lazySingleton
class GetSalesMetricsUseCase {
  final DashboardRepository repository;

  GetSalesMetricsUseCase(this.repository);

  Future<Either<Failure, SalesMetricsEntity>> call({
    required SalesTimeFilter filter,
  }) async {
    return await repository.getSalesMetrics(filter: filter);
  }
}
