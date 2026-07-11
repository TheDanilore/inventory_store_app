import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_model.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_inventory_entries_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries_state.dart';

@injectable
class InventoryEntriesCubit extends Cubit<InventoryEntriesState> {
  final GetInventoryEntriesUseCase getInventoryEntries;
  final GetActiveWarehousesUseCase getActiveWarehouses;
  static const int pageSize = 8;

  InventoryEntriesCubit({
    required this.getInventoryEntries,
    required this.getActiveWarehouses,
  }) : super(InventoryEntriesInitial());

  Future<void> init() async {
    List<String> warehouses = ['Todos'];
    try {
      final whList = await getActiveWarehouses.call();
      warehouses.addAll(whList.map((w) => w.name as String).toList());
    } catch (e) {
      debugPrint('Error cargando almacenes: $e');
    }

    emit(InventoryEntriesLoaded(
      entries: const [],
      searchQuery: '',
      warehouseFilter: 'Todos',
      dateRange: null,
      availableWarehouses: warehouses,
      currentPage: 0,
      totalCount: 0,
      totalPages: 1,
    ));

    await loadEntries(page: 0);
  }

  Future<void> loadEntries({
    String? searchQuery,
    String? warehouseFilter,
    DateTimeRange? dateRange,
    int? page,
    bool clearDateRange = false,
  }) async {
    final currentState = state is InventoryEntriesLoaded ? state as InventoryEntriesLoaded : null;
    if (currentState == null) return;

    final currentQuery = searchQuery ?? currentState.searchQuery;
    final currentWarehouse = warehouseFilter ?? currentState.warehouseFilter;
    final currentDateRange = clearDateRange ? null : (dateRange ?? currentState.dateRange);
    final currentPage = page ?? currentState.currentPage;

    emit(InventoryEntriesLoading());

    try {
      final start = currentPage * pageSize;
      final end = start + pageSize - 1;

      final response = await getInventoryEntries.call(
        start: start,
        end: end,
        searchQuery: currentQuery,
        warehouseFilter: currentWarehouse == 'Todos' ? null : currentWarehouse,
        dateRange: currentDateRange,
      );

      final dataList = response.data as List;
      final entries = dataList
          .map((e) => InventoryEntryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final totalRecords = response.count as int;
      final totalPages = (totalRecords / pageSize).ceil();

      emit(currentState.copyWith(
        entries: entries,
        searchQuery: currentQuery,
        warehouseFilter: currentWarehouse,
        dateRange: currentDateRange,
        clearDateRange: clearDateRange,
        currentPage: currentPage,
        totalCount: totalRecords,
        totalPages: totalPages == 0 ? 1 : totalPages,
      ));
    } catch (e) {
      debugPrint('Error loading inventory entries: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(const InventoryEntriesError('Sin conexión a internet.'));
      } else {
        emit(const InventoryEntriesError('Error al cargar entradas.'));
      }
      // Revertir a Loaded vacío si no había estado cargado válido
      emit(currentState);
    }
  }

  void setSearchQuery(String query) {
    if (state is InventoryEntriesLoaded && (state as InventoryEntriesLoaded).searchQuery == query) return;
    loadEntries(searchQuery: query, page: 0);
  }

  void setWarehouseFilter(String warehouse) {
    if (state is InventoryEntriesLoaded && (state as InventoryEntriesLoaded).warehouseFilter == warehouse) return;
    loadEntries(warehouseFilter: warehouse, page: 0);
  }

  void setDateRange(DateTimeRange? range) {
    loadEntries(dateRange: range, page: 0, clearDateRange: range == null);
  }

  void clearFilters() {
    loadEntries(
      searchQuery: '',
      warehouseFilter: 'Todos',
      clearDateRange: true,
      page: 0,
    );
  }

  void goToPage(int page) {
    if (state is InventoryEntriesLoaded) {
      final currentState = state as InventoryEntriesLoaded;
      if (page < 0 || page >= currentState.totalPages || page == currentState.currentPage) return;
      loadEntries(page: page);
    }
  }
}
