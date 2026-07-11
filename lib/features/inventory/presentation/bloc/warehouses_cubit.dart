import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_warehouses_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/save_warehouse_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/toggle_warehouse_status_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses_state.dart';

@injectable
class WarehousesCubit extends Cubit<WarehousesState> {
  final GetWarehousesUseCase getWarehousesUseCase;
  final SaveWarehouseUseCase saveWarehouseUseCase;
  final ToggleWarehouseStatusUseCase toggleWarehouseStatusUseCase;

  WarehousesCubit({
    required this.getWarehousesUseCase,
    required this.saveWarehouseUseCase,
    required this.toggleWarehouseStatusUseCase,
  }) : super(const WarehousesState());

  void initLoad() {
    loadWarehouses(isRefresh: true);
  }

  Future<void> loadWarehouses({bool isRefresh = false}) async {
    if (isRefresh) {
      emit(state.copyWith(currentPage: 0));
    }

    emit(state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      final start = state.currentPage * state.pageSize;
      final end = start + state.pageSize - 1;

      final response = await getWarehousesUseCase.call(
        start: start,
        end: end,
        searchQuery: state.searchQuery,
      );

      final dataList = response['data'] as List;
      final warehouses = dataList
          .map((e) => WarehouseModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final totalRecords = response['count'] as int;

      emit(state.copyWith(
        warehouses: warehouses,
        totalRecords: totalRecords,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Error al cargar almacenes',
        isLoading: false,
      ));
    }
  }

  void updateSearch(String query) {
    emit(state.copyWith(searchQuery: query));
    loadWarehouses(isRefresh: true);
  }

  void clearSearch() {
    emit(state.copyWith(searchQuery: ''));
    loadWarehouses(isRefresh: true);
  }

  void changePage(int page) {
    if (page >= 0 && page < state.totalPages && page != state.currentPage) {
      emit(state.copyWith(currentPage: page));
      loadWarehouses();
    }
  }

  Future<bool> saveWarehouse({
    WarehouseModel? existingWarehouse,
    required String name,
    required String address,
    required bool isActive,
  }) async {
    if (state.isSaving) return false;

    emit(state.copyWith(
      isSaving: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    ));

    try {
      await saveWarehouseUseCase.call(
        existingWarehouse: existingWarehouse,
        name: name,
        address: address,
        isActive: isActive,
      );

      emit(state.copyWith(
        isSaving: false,
        successMessage: existingWarehouse == null
            ? 'Almacén creado exitosamente'
            : 'Almacén actualizado',
      ));

      await loadWarehouses(isRefresh: true);
      return true;
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      String msg = 'Ocurrió un error inesperado al guardar el almacén.';
      if (errStr.contains('warehouses_name_key')) {
        msg = 'Ya existe un almacén con ese nombre.';
      } else if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        msg = 'Sin conexión a internet.';
      }

      emit(state.copyWith(
        isSaving: false,
        errorMessage: msg,
      ));
      return false;
    }
  }

  Future<void> toggleWarehouseStatus(WarehouseModel wh, bool isActive) async {
    try {
      await toggleWarehouseStatusUseCase.call(wh, isActive);
      
      emit(state.copyWith(
        successMessage: isActive ? 'Almacén activado' : 'Almacén desactivado',
        clearErrorMessage: true,
      ));

      await loadWarehouses();
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      String msg = 'Error al cambiar el estado del almacén.';
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        msg = 'Sin conexión a internet.';
      }

      emit(state.copyWith(
        errorMessage: msg,
        clearSuccessMessage: true,
      ));
    }
  }
}
