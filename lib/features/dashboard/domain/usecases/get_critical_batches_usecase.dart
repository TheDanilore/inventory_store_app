import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/dashboard/domain/repositories/dashboard_repository.dart';

@lazySingleton
class GetCriticalBatchesUseCase {
  final DashboardRepository repository;

  GetCriticalBatchesUseCase(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call({
    int daysThreshold = 30,
  }) async {
    return await repository.getCriticalBatches(daysThreshold: daysThreshold);
  }
}
