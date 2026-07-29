import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/kardex_repository.dart';

@injectable
class GetKardexMovementsUseCase {
  final KardexRepository repository;

  GetKardexMovementsUseCase(this.repository);

  /// Returns entities — for domain logic (e.g. PDF export)
  Future<List<KardexMovementEntity>> call({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    int page = 0,
    int pageSize = 12,
  }) {
    return repository.getKardexMovements(
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<int> count({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
  }) {
    return repository.getKardexMovementsCount(
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
    );
  }
}
