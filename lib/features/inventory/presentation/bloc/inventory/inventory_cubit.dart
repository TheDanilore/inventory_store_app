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
import 'package:inventory_store_app/core/services/logger_service.dart';

@injectable
class InventoryCubit extends Cubit<InventoryState> {
  final GetGeneralStockMetricsUseCase _getGeneralStockMetrics;
  final GetCategoriesUC _getCategories;
  final GetGeneralStockPaginatedUseCase _getGeneralStockPaginated;
  final GetBatchMetricsUseCase _getBatchMetrics;
  final GetBatchesPaginatedUseCase _getBatchesPaginated;
  final GetWarehousesUseCase _getWarehouses;

  static const int _stockPageSize = 24;
  static const int _batchPageSize = 24;

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
       super(const InventoryInitial());

  InventoryLoaded _getLoadedState({String? defaultSearchText}) {
    if (state is InventoryLoaded) {
      return state as InventoryLoaded;
    }
    return InventoryLoaded(
      stockItems: const [],
      batchItems: const [],
      currentStockPage: 0,
      totalStockPages: 1,
      stockSearchText: defaultSearchText ?? '',
      stockCategoryFilter: 'Todos',
      categories: const ['Todos'],
      warehouses: const [],
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

  Future<void> initStockTab({String? initialSearch}) async {
    final sanitizedSearch = initialSearch?.trim() ?? '';
    final isInitial = state is! InventoryLoaded;
    if (isInitial) {
      emit(const InventoryLoading());
    } else {
      final currentState = _getLoadedState(defaultSearchText: sanitizedSearch);
      emit(currentState.copyWith(
        isSearchingStock: true,
        stockSearchText: sanitizedSearch.isNotEmpty ? sanitizedSearch : currentState.stockSearchText,
      ));
    }

    try {
      var currentState = _getLoadedState(defaultSearchText: sanitizedSearch);
      if (sanitizedSearch.isNotEmpty) {
        currentState = currentState.copyWith(stockSearchText: sanitizedSearch);
      }

      final warehousesFuture = currentState.warehouses.isEmpty
          ? _getWarehouses(start: 0, end: 100)
              .then((res) => res.data.where((w) => w.isActive).toList())
              .catchError((e, stack) {
                LoggerService.e(
                  'Error cargando almacenes en InventoryCubit',
                  error: e,
                  stackTrace: stack,
                );
                return <WarehouseEntity>[];
              })
          : Future.value(currentState.warehouses);

      final categoriesFuture = currentState.categories.length <= 1
          ? _getCategories().then(
              (res) => res.fold(
                (l) => <String>['Todos'],
                (r) => <String>['Todos', ...r.map((c) => c.name)],
              ),
            )
          : Future.value(currentState.categories);

      final metricsFuture = _getGeneralStockMetrics(
        currentState.selectedWarehouseId,
      );

      final totalCountFuture = _getGeneralStockPaginated.getTotalCount(
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      final stockItemsFuture = _getGeneralStockPaginated(
        page: 0,
        pageSize: _stockPageSize,
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
        warehouseId: currentState.selectedWarehouseId,
      );

      final results = await Future.wait([
        warehousesFuture,
        categoriesFuture,
        metricsFuture,
        totalCountFuture,
        stockItemsFuture,
      ]);

      final warehouses = results[0] as List<WarehouseEntity>;
      final categoriesNames = results[1] as List<String>;
      final metrics = results[2] as Map<String, dynamic>;
      final totalStockCount = results[3] as int;
      final stockItems = results[4] as List<InventoryStockItem>;

      final totalPages =
          totalStockCount == 0 ? 1 : (totalStockCount / _stockPageSize).ceil();

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
          stockSearchText: currentState.stockSearchText,
          isSearchingStock: false,
        ),
      );
    } catch (e, stack) {
      LoggerService.e('Error en initStockTab de InventoryCubit', error: e, stackTrace: stack);
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
      final results = await Future.wait([
        _getGeneralStockPaginated.getTotalCount(
          search: currentState.stockSearchText,
          categoryName: currentState.stockCategoryFilter,
          warehouseId: currentState.selectedWarehouseId,
        ),
        _getGeneralStockPaginated(
          page: targetPage,
          pageSize: _stockPageSize,
          search: currentState.stockSearchText,
          categoryName: currentState.stockCategoryFilter,
          warehouseId: currentState.selectedWarehouseId,
        ),
      ]);

      final totalStockCount = results[0] as int;
      final stockItems = results[1] as List<InventoryStockItem>;

      int totalPages =
          totalStockCount == 0 ? 1 : (totalStockCount / _stockPageSize).ceil();
      int validPage = targetPage >= totalPages ? 0 : targetPage;

      emit(
        currentState.copyWith(
          currentStockPage: validPage,
          totalStockPages: totalPages,
          stockItems: stockItems,
          isSearchingStock: false,
        ),
      );
    } catch (e, stack) {
      LoggerService.e('Error en fetchStockPage de InventoryCubit', error: e, stackTrace: stack);
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
    final cleanText = text.trim();
    final currentState = _getLoadedState();
    if (currentState.stockSearchText == cleanText) return;
    emit(currentState.copyWith(stockSearchText: cleanText));
    fetchStockPage(page: 0);
  }

  void setStockCategory(String category) {
    final currentState = _getLoadedState();
    if (currentState.stockCategoryFilter == category) return;
    emit(currentState.copyWith(stockCategoryFilter: category));
    fetchStockPage(page: 0);
  }

  void refreshAll() {
    initStockTab();
  }

  Future<void> initBatchesTab() async {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(isSearchingBatches: true));

    try {
      final results = await Future.wait([
        _getBatchMetrics(
          search: currentState.batchSearchText,
          warehouseId: currentState.selectedWarehouseId,
        ),
        _getBatchesPaginated.getTotalCount(
          search: currentState.batchSearchText,
          statusFilter: currentState.batchStatusFilter,
          warehouseId: currentState.selectedWarehouseId,
        ),
        _getBatchesPaginated(
          page: 0,
          pageSize: _batchPageSize,
          search: currentState.batchSearchText,
          statusFilter: currentState.batchStatusFilter,
          warehouseId: currentState.selectedWarehouseId,
        ),
      ]);

      final metrics = results[0] as Map<String, dynamic>;
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
    } catch (e, stack) {
      LoggerService.e('Error en initBatchesTab de InventoryCubit', error: e, stackTrace: stack);
      final stateNow = _getLoadedState();
      emit(stateNow.copyWith(isSearchingBatches: false));
    }
  }

  Future<void> fetchBatchPage({int? page}) async {
    final currentState = _getLoadedState();
    final targetPage = page ?? currentState.currentBatchPage;

    emit(currentState.copyWith(isSearchingBatches: true));
    try {
      final results = await Future.wait([
        _getBatchesPaginated.getTotalCount(
          search: currentState.batchSearchText,
          statusFilter: currentState.batchStatusFilter,
          warehouseId: currentState.selectedWarehouseId,
        ),
        _getBatchesPaginated(
          page: targetPage,
          pageSize: _batchPageSize,
          search: currentState.batchSearchText,
          statusFilter: currentState.batchStatusFilter,
          warehouseId: currentState.selectedWarehouseId,
        ),
      ]);

      final totalBatchCount = results[0] as int;
      final batchItems = results[1] as List<InventoryBatchItem>;

      int totalPages =
          totalBatchCount == 0 ? 1 : (totalBatchCount / _batchPageSize).ceil();
      int validPage = targetPage >= totalPages ? 0 : targetPage;

      emit(
        currentState.copyWith(
          currentBatchPage: validPage,
          totalBatchPages: totalPages,
          batchItems: batchItems,
          isSearchingBatches: false,
        ),
      );
    } catch (e, stack) {
      LoggerService.e('Error en fetchBatchPage de InventoryCubit', error: e, stackTrace: stack);
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
    final cleanText = text.trim();
    final currentState = _getLoadedState();
    emit(currentState.copyWith(
      batchSearchText: cleanText,
      currentBatchPage: 0,
      isSearchingBatches: true,
    ));

    try {
      final metricsFuture = _getBatchMetrics(
        search: cleanText,
        warehouseId: currentState.selectedWarehouseId,
      );
      final totalBatchCountFuture = _getBatchesPaginated.getTotalCount(
        search: cleanText,
        statusFilter: currentState.batchStatusFilter,
        warehouseId: currentState.selectedWarehouseId,
      );
      final batchItemsFuture = _getBatchesPaginated(
        page: 0,
        pageSize: _batchPageSize,
        search: cleanText,
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
    } catch (e, stack) {
      LoggerService.e('Error en setBatchSearch de InventoryCubit', error: e, stackTrace: stack);
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
    } catch (e, stack) {
      LoggerService.e('Error en setWarehouseFilter de InventoryCubit', error: e, stackTrace: stack);
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
