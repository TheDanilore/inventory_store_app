import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_batches_paginated_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_general_stock_metrics_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_general_stock_paginated_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_batch_metrics_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_warehouses_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';

@injectable
class InventoryCubit extends Cubit<InventoryState> {
  final GetGeneralStockMetricsUseCase _getGeneralStockMetrics;
  final GetCategoriesUC _getCategories;
  final GetGeneralStockPaginatedUseCase _getGeneralStockPaginated;
  final GetBatchMetricsUseCase _getBatchMetrics;
  final GetBatchesPaginatedUseCase _getBatchesPaginated;
  final GetWarehousesUseCase _getWarehouses;

  static const int _stockPageSize = 8;
  static const int _batchPageSize = 8;

  InventoryCubit({
    required GetGeneralStockMetricsUseCase getGeneralStockMetrics,
    required GetCategoriesUC getCategories,
    required GetGeneralStockPaginatedUseCase getGeneralStockPaginated,
    required GetBatchMetricsUseCase getBatchMetrics,
    required GetBatchesPaginatedUseCase getBatchesPaginated,
    required GetWarehousesUseCase getWarehouses,
  }) : _getGeneralStockMetrics = getGeneralStockMetrics,
       _getCategories = getCategories,
       _getGeneralStockPaginated = getGeneralStockPaginated,
       _getBatchMetrics = getBatchMetrics,
       _getBatchesPaginated = getBatchesPaginated,
       _getWarehouses = getWarehouses,
       super(const InventoryInitial()) {
    initStockTab();
  }

  InventoryLoaded _getLoadedState() {
    if (state is InventoryLoaded) {
      return state as InventoryLoaded;
    }
    return const InventoryLoaded(
      stockItems: [],
      batchItems: [],
      currentStockPage: 0,
      totalStockPages: 1,
      stockSearchText: '',
      stockCategoryFilter: 'Todos',
      categories: ['Todos'],
      warehouses: [],
      selectedWarehouseId: null,
      selectedWarehouseName: 'Todos los almacenes',
      globalTotalVariants: 0,
      globalTotalStock: 0,
      globalLowStockCount: 0,
      globalTotalCost: 0.0,
      currentBatchPage: 0,
      totalBatchPages: 1,
      batchSearchText: '',
      batchStatusFilter: 'Todos',
      countVencido: 0,
      countCritico: 0,
      countProximo: 0,
      countNormal: 0,
    );
  }

  Future<void> initStockTab() async {
    final isInitial = state is! InventoryLoaded;
    if (isInitial) {
      emit(const InventoryLoading());
    } else {
      final currentState = _getLoadedState();
      emit(currentState.copyWith(isSearchingStock: true));
    }

    try {
      final currentState = _getLoadedState();

      List<WarehouseEntity> warehouses = currentState.warehouses;
      if (warehouses.isEmpty) {
        try {
          final whRes = await _getWarehouses(start: 0, end: 100);
          warehouses = whRes.data.where((w) => w.isActive).toList();
        } catch (_) {}
      }

      final categoriesResult = await _getCategories();
      final categoriesNames = categoriesResult.fold(
        (l) => <String>['Todos'],
        (r) => <String>['Todos', ...r.map((c) => c.name)],
      );
      final metrics = await _getGeneralStockMetrics(
        currentState.selectedWarehouseId,
      );

      final totalStockCount = await _getGeneralStockPaginated.getTotalCount(
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      final totalPages =
          totalStockCount == 0 ? 1 : (totalStockCount / _stockPageSize).ceil();

      final stockItems = await _getGeneralStockPaginated(
        page: 0,
        pageSize: _stockPageSize,
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      emit(
        currentState.copyWith(
          categories: categoriesNames,
          warehouses: warehouses,
          globalTotalVariants: metrics['totalVariants'] ?? 0,
          globalTotalStock: metrics['totalStock'] ?? 0,
          globalLowStockCount: metrics['lowStockCount'] ?? 0,
          globalTotalCost: (metrics['totalCost'] as num?)?.toDouble() ?? 0.0,
          currentStockPage: 0,
          totalStockPages: totalPages,
          stockItems: stockItems,
          isSearchingStock: false,
        ),
      );
    } catch (e) {
      if (isInitial) {
        emit(InventoryError(e.toString()));
      } else {
        final stateNow = _getLoadedState();
        emit(stateNow.copyWith(isSearchingStock: false));
      }
    }
  }

  Future<void> fetchStockPage({int? page}) async {
    final currentState = _getLoadedState();
    final targetPage = page ?? currentState.currentStockPage;

    emit(currentState.copyWith(isSearchingStock: true));
    try {
      final totalStockCount = await _getGeneralStockPaginated.getTotalCount(
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      int totalPages =
          totalStockCount == 0 ? 1 : (totalStockCount / _stockPageSize).ceil();
      int validPage = targetPage >= totalPages ? 0 : targetPage;

      final stockItems = await _getGeneralStockPaginated(
        page: validPage,
        pageSize: _stockPageSize,
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      emit(
        currentState.copyWith(
          currentStockPage: validPage,
          totalStockPages: totalPages,
          stockItems: stockItems,
          isSearchingStock: false,
        ),
      );
    } catch (e) {
      final stateNow = _getLoadedState();
      emit(stateNow.copyWith(isSearchingStock: false));
    }
  }

  void setStockPage(int page) {
    if (state is InventoryLoaded &&
        page == (state as InventoryLoaded).currentStockPage) {
      return;
    }
    fetchStockPage(page: page);
  }

  void setStockSearch(String text) {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(
      stockSearchText: text,
      currentStockPage: 0,
      isSearchingStock: true,
    ));
    fetchStockPage(page: 0);
  }

  void setStockCategory(String cat) {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(
      stockCategoryFilter: cat,
      currentStockPage: 0,
      isSearchingStock: true,
    ));
    fetchStockPage(page: 0);
  }

  Future<void> initBatchesTab() async {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(isSearchingBatches: true));

    try {
      final metrics = await _getBatchMetrics(
        search: currentState.batchSearchText,
        warehouseId: currentState.selectedWarehouseId,
      );

      final totalBatchCount = await _getBatchesPaginated.getTotalCount(
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      final totalPages =
          totalBatchCount == 0 ? 1 : (totalBatchCount / _batchPageSize).ceil();

      final batchItems = await _getBatchesPaginated(
        page: 0,
        pageSize: _batchPageSize,
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      final updatedState = _getLoadedState();
      emit(
        updatedState.copyWith(
          countVencido: metrics['vencido'] ?? 0,
          countCritico: metrics['critico'] ?? 0,
          countProximo: metrics['proximo'] ?? 0,
          countNormal: metrics['normal'] ?? 0,
          currentBatchPage: 0,
          totalBatchPages: totalPages,
          batchItems: batchItems,
          isSearchingBatches: false,
        ),
      );
    } catch (e) {
      final stateNow = _getLoadedState();
      emit(stateNow.copyWith(isSearchingBatches: false));
    }
  }

  Future<void> fetchBatchPage({int? page}) async {
    final currentState = _getLoadedState();
    final targetPage = page ?? currentState.currentBatchPage;

    emit(currentState.copyWith(isSearchingBatches: true));
    try {
      final totalBatchCount = await _getBatchesPaginated.getTotalCount(
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      int totalPages =
          totalBatchCount == 0 ? 1 : (totalBatchCount / _batchPageSize).ceil();
      int validPage = targetPage >= totalPages ? 0 : targetPage;

      final batchItems = await _getBatchesPaginated(
        page: validPage,
        pageSize: _batchPageSize,
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      emit(
        currentState.copyWith(
          currentBatchPage: validPage,
          totalBatchPages: totalPages,
          batchItems: batchItems,
          isSearchingBatches: false,
        ),
      );
    } catch (e) {
      final stateNow = _getLoadedState();
      emit(stateNow.copyWith(isSearchingBatches: false));
    }
  }

  void setBatchPage(int page) {
    if (state is InventoryLoaded &&
        page == (state as InventoryLoaded).currentBatchPage) {
      return;
    }
    fetchBatchPage(page: page);
  }

  void setBatchSearch(String text) async {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(
      batchSearchText: text,
      currentBatchPage: 0,
      isSearchingBatches: true,
    ));

    try {
      final metricsFuture = _getBatchMetrics(
        search: text,
        warehouseId: currentState.selectedWarehouseId,
      );
      final totalBatchCountFuture = _getBatchesPaginated.getTotalCount(
        search: text,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: currentState.selectedWarehouseId,
      );
      final batchItemsFuture = _getBatchesPaginated(
        page: 0,
        pageSize: _batchPageSize,
        search: text,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      final results = await Future.wait([
        metricsFuture,
        totalBatchCountFuture,
        batchItemsFuture,
      ]);

      final metrics = results[0] as Map<String, int>;
      final totalBatchCount = results[1] as int;
      final batchItems = results[2] as List<InventoryBatchItem>;

      final totalPages =
          totalBatchCount == 0 ? 1 : (totalBatchCount / _batchPageSize).ceil();

      final updatedState = _getLoadedState();
      emit(
        updatedState.copyWith(
          countVencido: metrics['vencido'] ?? 0,
          countCritico: metrics['critico'] ?? 0,
          countProximo: metrics['proximo'] ?? 0,
          countNormal: metrics['normal'] ?? 0,
          currentBatchPage: 0,
          totalBatchPages: totalPages,
          batchItems: batchItems,
          isSearchingBatches: false,
        ),
      );
    } catch (e) {
      final updatedState = _getLoadedState();
      emit(updatedState.copyWith(isSearchingBatches: false));
    }
  }

  void setBatchStatus(String status) {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(
      batchStatusFilter: status,
      currentBatchPage: 0,
      isSearchingBatches: true,
    ));
    fetchBatchPage(page: 0);
  }

  Future<void> setWarehouseFilter(
    String? warehouseId, [
    String warehouseName = 'Todos los almacenes',
  ]) async {
    final currentState = _getLoadedState();
    if (currentState.selectedWarehouseId == warehouseId) return;

    emit(
      currentState.copyWith(
        selectedWarehouseId: warehouseId,
        selectedWarehouseName: warehouseName,
        clearWarehouseId: warehouseId == null,
        isSearchingStock: true,
        isSearchingBatches: true,
        currentStockPage: 0,
        currentBatchPage: 0,
      ),
    );

    try {
      final stockMetricsFuture = _getGeneralStockMetrics(warehouseId);
      final totalStockCountFuture = _getGeneralStockPaginated.getTotalCount(
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: warehouseId,
      );
      final stockItemsFuture = _getGeneralStockPaginated(
        page: 0,
        pageSize: _stockPageSize,
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: warehouseId,
      );

      final batchMetricsFuture = _getBatchMetrics(
        search: currentState.batchSearchText,
        warehouseId: warehouseId,
      );
      final totalBatchCountFuture = _getBatchesPaginated.getTotalCount(
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: warehouseId,
      );
      final batchItemsFuture = _getBatchesPaginated(
        page: 0,
        pageSize: _batchPageSize,
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: warehouseId,
      );

      final results = await Future.wait([
        stockMetricsFuture,
        totalStockCountFuture,
        stockItemsFuture,
        batchMetricsFuture,
        totalBatchCountFuture,
        batchItemsFuture,
      ]);

      final stockMetrics = results[0] as Map<String, dynamic>;
      final totalStockCount = results[1] as int;
      final stockItems = results[2] as List<InventoryStockItem>;
      final batchMetrics = results[3] as Map<String, int>;
      final totalBatchCount = results[4] as int;
      final batchItems = results[5] as List<InventoryBatchItem>;

      final totalStockPages =
          totalStockCount == 0 ? 1 : (totalStockCount / _stockPageSize).ceil();
      final totalBatchPages =
          totalBatchCount == 0 ? 1 : (totalBatchCount / _batchPageSize).ceil();

      final updatedState = _getLoadedState();
      emit(
        updatedState.copyWith(
          globalTotalVariants: stockMetrics['totalVariants'] ?? 0,
          globalTotalStock: stockMetrics['totalStock'] ?? 0,
          globalLowStockCount: stockMetrics['lowStockCount'] ?? 0,
          globalTotalCost:
              (stockMetrics['totalCost'] as num?)?.toDouble() ?? 0.0,
          currentStockPage: 0,
          totalStockPages: totalStockPages,
          stockItems: stockItems,
          isSearchingStock: false,
          countVencido: batchMetrics['vencido'] ?? 0,
          countCritico: batchMetrics['critico'] ?? 0,
          countProximo: batchMetrics['proximo'] ?? 0,
          countNormal: batchMetrics['normal'] ?? 0,
          currentBatchPage: 0,
          totalBatchPages: totalBatchPages,
          batchItems: batchItems,
          isSearchingBatches: false,
        ),
      );
    } catch (e) {
      final stateNow = _getLoadedState();
      emit(
        stateNow.copyWith(
          isSearchingStock: false,
          isSearchingBatches: false,
        ),
      );
    }
  }
}
