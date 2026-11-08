import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_inventory_exits_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits/inventory_exits_state.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_exit_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_item_model.dart';

@lazySingleton
class InventoryExitsCubit extends Cubit<InventoryExitsState> {
  final GetInventoryExitsUseCase getExitsUseCase;
  final GetExitItemsUseCase getItemsUseCase;
  final GetActiveWarehousesUseCase getActiveWarehouses;

  // Cache L1 en memoria para detalles de salidas ya consultadas (evita roundtrips repetidos)
  final Map<String, List<InventoryExitItemModel>> _exitItemsCache = {};

  InventoryExitsCubit({
    required this.getExitsUseCase,
    required this.getItemsUseCase,
    GetActiveWarehousesUseCase? getActiveWarehouses,
  }) : getActiveWarehouses =
           getActiveWarehouses ?? sl<GetActiveWarehousesUseCase>(),
       super(const InventoryExitsState());

  /// Invalida la caché del listado en memoria y recarga en caliente.
  static void invalidateCache() {
    if (sl.isRegistered<InventoryExitsCubit>()) {
      sl<InventoryExitsCubit>()._onCacheInvalidated();
    }
  }

  void _onCacheInvalidated() {
    _exitItemsCache.clear();
    loadExits(isRefresh: true, isSilent: false);
  }

  /// Carga inicial con garantía Zero-Shimmer (Stale-While-Revalidate).
  /// Si ya existen datos en memoria, se muestran de inmediato en Frame 0 (0ms)
  /// y se revalida en background sin activar shimmer ni spinner.
  Future<void> initLoad({bool forceRefresh = false}) async {
    final hasCachedData = state.exits.isNotEmpty;

    // Carga perezosa de almacenes solo una vez
    if (state.availableWarehouses.length <= 1) {
      try {
        final whList = await getActiveWarehouses.call();
        final warehouses = ['Todos', ...whList.map((w) => w.name)];
        emit(state.copyWith(availableWarehouses: warehouses));
      } catch (e, st) {
        developer.log(
          'Error al cargar almacenes activos',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (hasCachedData && !forceRefresh) {
      // Política Zero-Shimmer (SWR): Datos presentes -> Revalidación silenciosa en background
      await loadExits(isRefresh: false, isSilent: true);
    } else {
      await loadExits(isRefresh: true, isSilent: false);
    }
  }

  Future<void> loadExits({
    bool isRefresh = false,
    bool isSilent = false,
  }) async {
    if (isRefresh) {
      emit(state.copyWith(currentPage: 0));
    }

    if (!isSilent) {
      emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    }

    try {
      final int start = state.currentPage * state.pageSize;
      final int end = start + state.pageSize - 1;

      final warehouseFilter =
          (state.warehouseFilter == 'Todos' || state.warehouseFilter == 'TODOS')
              ? null
              : state.warehouseFilter;

      final response = await getExitsUseCase.call(
        start: start,
        end: end,
        searchQuery: state.searchQuery,
        warehouseFilter: warehouseFilter,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      final dataList = response.data;
      final exits = List<InventoryExitEntity>.from(dataList);
      final totalRecords = response.count;

      emit(
        state.copyWith(
          exits: exits,
          totalRecords: totalRecords,
          isLoading: false,
        ),
      );
    } catch (e, st) {
      developer.log(
        'Error al cargar salidas de inventario',
        error: e,
        stackTrace: st,
      );
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(
          state.copyWith(
            errorMessage: 'Sin conexión a internet.',
            isLoading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            errorMessage: 'Error al cargar salidas.',
            isLoading: false,
          ),
        );
      }
    }
  }

  void nextPage() {
    if (state.currentPage < state.totalPages - 1) {
      emit(state.copyWith(currentPage: state.currentPage + 1));
      loadExits();
    }
  }

  void previousPage() {
    if (state.currentPage > 0) {
      emit(state.copyWith(currentPage: state.currentPage - 1));
      loadExits();
    }
  }

  void changePage(int page) {
    if (page >= 0 && page < state.totalPages) {
      emit(state.copyWith(currentPage: page));
      loadExits();
    }
  }

  void updateSearch(String query) {
    if (state.searchQuery == query) return;
    emit(state.copyWith(searchQuery: query));
    loadExits(isRefresh: true);
  }

  void updateDateRange(DateTime? startDate, DateTime? endDate) {
    emit(
      state.copyWith(
        startDate: startDate,
        endDate: endDate,
        clearDateRange: startDate == null && endDate == null,
      ),
    );
    loadExits(isRefresh: true);
  }

  void updateWarehouse(String warehouse) {
    if (state.warehouseFilter == warehouse) return;
    emit(state.copyWith(warehouseFilter: warehouse));
    loadExits(isRefresh: true);
  }

  void clearFilters() {
    emit(
      state.copyWith(
        searchQuery: '',
        warehouseFilter: 'Todos',
        clearDateRange: true,
      ),
    );
    loadExits(isRefresh: true);
  }

  /// Carga los items de una salida con caché L1 en memoria (0ms en reapertura).
  Future<List<InventoryExitItemModel>> loadExitItems(String exitId) async {
    if (_exitItemsCache.containsKey(exitId)) {
      return _exitItemsCache[exitId]!;
    }

    try {
      final itemsList = await getItemsUseCase.call(exitId);
      final parsed =
          itemsList.map((r) {
            final prod = r['products'] as Map<String, dynamic>?;
            final variant = r['product_variants'] as Map<String, dynamic>?;
            final variantId = r['variant_id'] as String?;

            final vavList =
                variant?['variant_attribute_values'] as List<dynamic>? ?? [];
            final List<String> attrValues = [];
            for (var vav in vavList) {
              final av = vav['attribute_values'] as Map<String, dynamic>?;
              if (av != null && av['value'] != null) {
                attrValues.add(av['value'].toString());
              }
            }
            final attrsText = attrValues.join(' · ');
            final bool usesBatches = prod?['uses_batches'] == true;

            String? finalImageUrl;
            final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
            if (imagesList.isNotEmpty) {
              final variantImage = imagesList
                  .cast<Map<String, dynamic>>()
                  .firstWhere(
                    (img) => img['variant_id'] == variantId,
                    orElse: () => <String, dynamic>{},
                  );
              if (variantImage.isNotEmpty &&
                  variantImage['image_url'] != null) {
                finalImageUrl = variantImage['image_url'] as String;
              } else {
                final mainImage = imagesList
                    .cast<Map<String, dynamic>>()
                    .firstWhere(
                      (img) => img['is_main'] == true,
                      orElse: () => imagesList.first as Map<String, dynamic>,
                    );
                finalImageUrl = mainImage['image_url'] as String?;
              }
            }

            return InventoryExitItemModel(
              id: r['id'] as String? ?? '',
              exitId: exitId,
              productId: prod?['id'] as String? ?? '',
              variantId: variantId ?? '',
              productName: prod?['name'] as String? ?? '—',
              variantAttrs: attrsText.isNotEmpty ? attrsText : '',
              quantity: (r['quantity'] as num).toDouble(),
              unitCost: (r['unit_cost'] as num).toDouble(),
              batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
              usesBatches: usesBatches,
              imageUrl: finalImageUrl,
              sku: variant?['sku'] as String?,
            );
          }).toList();

      _exitItemsCache[exitId] = parsed;
      return parsed;
    } catch (e, st) {
      developer.log(
        'Error loading exit items for $exitId',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
