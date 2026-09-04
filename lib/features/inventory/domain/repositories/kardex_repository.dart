import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

abstract class KardexRepository {
  /// Returns entities — used by domain use cases (PDF export, etc.)
  Future<({List<KardexMovementEntity> movements, int totalCount})>
  getKardexMovements({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
    int page = 0,
    int pageSize = 12,
  });

  Future<List<KardexMovementEntity>> getAllKardexMovements({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
  });
}
