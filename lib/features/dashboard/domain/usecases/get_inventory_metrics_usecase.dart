import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/repositories/dashboard_repository.dart';

@lazySingleton
class GetInventoryMetricsUseCase {
  final DashboardRepository repository;

  GetInventoryMetricsUseCase(this.repository);

  Future<Either<Failure, InventoryMetricsEntity>> call() async {
    return await repository.getInventoryMetrics();
  }
}
