import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/kardex_repository.dart';

@injectable
class GetKardexMovementsUseCase {
  final KardexRepository repository;

  GetKardexMovementsUseCase(this.repository);

  /// Returns entities and total count
  Future<({List<KardexMovementEntity> movements, int totalCount})> call({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
    String? batchId,
    int page = 0,
    int pageSize = 12,
  }) {
    return repository.getKardexMovements(
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
      productId: productId,
      variantId: variantId,
      batchId: batchId,
      page: page,
      pageSize: pageSize,
    );
  }
}
