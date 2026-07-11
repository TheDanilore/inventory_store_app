import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_general_stock_metrics_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_general_stock_paginated_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_batch_metrics_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_batches_paginated_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_state.dart';

@injectable
class InventoryCubit extends Cubit<InventoryState> {
  final GetGeneralStockMetricsUseCase _getGeneralStockMetrics;
  final GetCategoriesUC _getCategories;
  final GetGeneralStockPaginatedUseCase _getGeneralStockPaginated;
  final GetBatchMetricsUseCase _getBatchMetrics;
  final GetBatchesPaginatedUseCase _getBatchesPaginated;

  static const int _stockPageSize = 8;
  static const int _batchPageSize = 8;

  InventoryCubit({
    required GetGeneralStockMetricsUseCase getGeneralStockMetrics,
    required GetCategoriesUC getCategories,
    required GetGeneralStockPaginatedUseCase getGeneralStockPaginated,
    required GetBatchMetricsUseCase getBatchMetrics,
    required GetBatchesPaginatedUseCase getBatchesPaginated,
  })  : _getGeneralStockMetrics = getGeneralStockMetrics,
        _getCategories = getCategories,
        _getGeneralStockPaginated = getGeneralStockPaginated,
        _getBatchMetrics = getBatchMetrics,
        _getBatchesPaginated = getBatchesPaginated,
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
    emit(const InventoryLoading());
    try {
      final categories = await _getCategories(NoParams());
      final metrics = await _getGeneralStockMetrics(NoParams());
      
      final currentState = _getLoadedState();
      
      final totalStockCount = await _getGeneralStockPaginated.getTotalCount(
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
      );

      final totalPages = totalStockCount == 0 ? 1 : (totalStockCount / _stockPageSize).ceil();

      final stockItems = await _getGeneralStockPaginated(
        page: 0,
        pageSize: _stockPageSize,
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
      );

      emit(currentState.copyWith(
        categories: categories,
        globalTotalVariants: metrics['totalVariants'] ?? 0,
        globalTotalStock: metrics['totalStock'] ?? 0,
        globalLowStockCount: metrics['lowStockCount'] ?? 0,
        globalTotalCost: (metrics['totalCost'] as num?)?.toDouble() ?? 0.0,
        currentStockPage: 0,
        totalStockPages: totalPages,
        stockItems: stockItems,
      ));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> fetchStockPage({int? page}) async {
    final currentState = _getLoadedState();
    final targetPage = page ?? currentState.currentStockPage;
    
    emit(const InventoryLoading());
    try {
      final totalStockCount = await _getGeneralStockPaginated.getTotalCount(
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
      );
      
      int totalPages = totalStockCount == 0 ? 1 : (totalStockCount / _stockPageSize).ceil();
      int validPage = targetPage >= totalPages ? 0 : targetPage;

      final stockItems = await _getGeneralStockPaginated(
        page: validPage,
        pageSize: _stockPageSize,
        search: currentState.stockSearchText,
        categoryName: currentState.stockCategoryFilter,
      );

      emit(currentState.copyWith(
        currentStockPage: validPage,
        totalStockPages: totalPages,
        stockItems: stockItems,
      ));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  void setStockPage(int page) {
    if (state is InventoryLoaded && page == (state as InventoryLoaded).currentStockPage) return;
    fetchStockPage(page: page);
  }

  void setStockSearch(String text) {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(stockSearchText: text, currentStockPage: 0));
    fetchStockPage(page: 0);
  }

  void setStockCategory(String cat) {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(stockCategoryFilter: cat, currentStockPage: 0));
    fetchStockPage(page: 0);
  }

  Future<void> initBatchesTab() async {
    final currentState = _getLoadedState();
    emit(const InventoryLoading());
    try {
      final metrics = await _getBatchMetrics(search: currentState.batchSearchText);
      
      final totalBatchCount = await _getBatchesPaginated.getTotalCount(
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
      );

      final totalPages = totalBatchCount == 0 ? 1 : (totalBatchCount / _batchPageSize).ceil();

      final batchItems = await _getBatchesPaginated(
        page: 0,
        pageSize: _batchPageSize,
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
      );

      emit(currentState.copyWith(
        countVencido: metrics['vencido'] ?? 0,
        countCritico: metrics['critico'] ?? 0,
        countProximo: metrics['proximo'] ?? 0,
        countNormal: metrics['normal'] ?? 0,
        currentBatchPage: 0,
        totalBatchPages: totalPages,
        batchItems: batchItems,
      ));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  Future<void> fetchBatchPage({int? page}) async {
    final currentState = _getLoadedState();
    final targetPage = page ?? currentState.currentBatchPage;
    
    emit(const InventoryLoading());
    try {
      final totalBatchCount = await _getBatchesPaginated.getTotalCount(
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
      );
      
      int totalPages = totalBatchCount == 0 ? 1 : (totalBatchCount / _batchPageSize).ceil();
      int validPage = targetPage >= totalPages ? 0 : targetPage;

      final batchItems = await _getBatchesPaginated(
        page: validPage,
        pageSize: _batchPageSize,
        search: currentState.batchSearchText,
        statusFilter: currentState.batchStatusFilter,
      );

      emit(currentState.copyWith(
        currentBatchPage: validPage,
        totalBatchPages: totalPages,
        batchItems: batchItems,
      ));
    } catch (e) {
      emit(InventoryError(e.toString()));
    }
  }

  void setBatchPage(int page) {
    if (state is InventoryLoaded && page == (state as InventoryLoaded).currentBatchPage) return;
    fetchBatchPage(page: page);
  }

  void setBatchSearch(String text) async {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(batchSearchText: text, currentBatchPage: 0));
    
    // Al buscar, se actualizan las metricas ademas de la pagina
    emit(const InventoryLoading());
    try {
      final metrics = await _getBatchMetrics(search: text);
      final updatedState = _getLoadedState();
      emit(updatedState.copyWith(
        countVencido: metrics['vencido'] ?? 0,
        countCritico: metrics['critico'] ?? 0,
        countProximo: metrics['proximo'] ?? 0,
        countNormal: metrics['normal'] ?? 0,
      ));
      await fetchBatchPage(page: 0);
    } catch(e) {
       emit(InventoryError(e.toString()));
    }
  }

  void setBatchStatus(String status) {
    final currentState = _getLoadedState();
    emit(currentState.copyWith(batchStatusFilter: status, currentBatchPage: 0));
    fetchBatchPage(page: 0);
  }
}
