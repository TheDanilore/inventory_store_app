import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';

abstract class InventoryRepository {
  Future<Map<String, dynamic>> getGeneralStockMetrics();
  
  Future<int> getTotalGeneralStockCount({
    String search = '',
    String categoryName = 'Todos',
  });

  Future<List<InventoryStockItem>> getGeneralStockPaginated({
    required int page,
    required int pageSize,
    String search = '',
    String categoryName = 'Todos',
  });

  Future<Map<String, int>> getBatchMetrics({String search = ''});

  Future<int> getTotalBatchesCount({
    String search = '',
    String statusFilter = 'Todos',
  });

  Future<List<InventoryBatchItem>> getBatchesPaginated({
    required int page,
    required int pageSize,
    String search = '',
    String statusFilter = 'Todos',
  });
}
