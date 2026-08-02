import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_suppliers_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/toggle_supplier_status_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/save_supplier_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';

@injectable
class SuppliersCubit extends Cubit<SuppliersState> {
  final FetchSuppliersUseCase fetchSuppliersUseCase;
  final ToggleSupplierStatusUseCase toggleSupplierStatusUseCase;
  final SaveSupplierUseCase saveSupplierUseCase;

  static const int pageSize = 8;

  SuppliersCubit({
    required this.fetchSuppliersUseCase,
    required this.toggleSupplierStatusUseCase,
    required this.saveSupplierUseCase,
  }) : super(SuppliersInitial()) {
    loadSuppliers();
  }

  Future<void> loadSuppliers({
    String? searchQuery,
    int? page,
    bool refresh = false,
  }) async {
    final currentState = state;
    String currentQuery = '';
    int currentPage = 0;
    List<SupplierEntity> currentSuppliers = [];
    int currentTotalCount = 0;

    if (currentState is SuppliersLoaded) {
      currentQuery = searchQuery ?? currentState.searchQuery;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentSuppliers = refresh ? [] : currentState.suppliers;
      currentTotalCount = currentState.totalCount;
    } else if (currentState is SuppliersLoading) {
      currentQuery = searchQuery ?? currentState.searchQuery;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentSuppliers = refresh ? [] : currentState.currentSuppliers;
      currentTotalCount = currentState.totalCount;
    } else if (currentState is SuppliersError) {
      currentQuery = searchQuery ?? currentState.searchQuery;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentSuppliers = refresh ? [] : currentState.currentSuppliers;
      currentTotalCount = currentState.totalCount;
    } else {
      currentQuery = searchQuery ?? '';
      currentPage = page ?? 0;
    }

    emit(
      SuppliersLoading(
        currentSuppliers: currentSuppliers,
        searchQuery: currentQuery,
        currentPage: currentPage,
        totalCount: currentTotalCount,
      ),
    );

    final result = await fetchSuppliersUseCase(
      page: currentPage,
      pageSize: pageSize,
      searchQuery: currentQuery,
    );

    result.fold(
      (failure) {
        String msg = 'Error al cargar proveedores.';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(
          SuppliersError(
            message: msg,
            currentSuppliers: currentSuppliers,
            searchQuery: currentQuery,
            currentPage: currentPage,
            totalCount: currentTotalCount,
          ),
        );
      },
      (data) {
        emit(
          SuppliersLoaded(
            suppliers: data.suppliers,
            searchQuery: currentQuery,
            currentPage: currentPage,
            totalCount: data.totalCount,
          ),
        );
      },
    );
  }

  void setSearchQuery(String query) {
    loadSuppliers(searchQuery: query, page: 0, refresh: true);
  }

  void setPage(int page) {
    loadSuppliers(page: page);
  }

  Future<void> toggleSupplierStatus(SupplierEntity supplier) async {
    final currentState = state;
    if (currentState is! SuppliersLoaded) return;

    final result = await toggleSupplierStatusUseCase(
      supplier.id,
      supplier.isActive,
    );

    result.fold(
      (failure) {
        String msg = 'Error al cambiar estado.';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(
          SuppliersError(
            message: msg,
            currentSuppliers: currentState.suppliers,
            searchQuery: currentState.searchQuery,
            currentPage: currentState.currentPage,
            totalCount: currentState.totalCount,
          ),
        );
      },
      (_) {
        final updatedSuppliers =
            currentState.suppliers.map((s) {
              if (s.id == supplier.id) {
                return s.copyWith(isActive: !s.isActive);
              }
              return s;
            }).toList();

        emit(currentState.copyWith(suppliers: updatedSuppliers));
      },
    );
  }

  Future<void> saveSupplier(SupplierEntity supplier) async {
    final currentState = state;

    // We only process if we are currently displaying a loaded state or an error state from a previous attempt
    List<SupplierEntity> currentList = [];
    String query = '';
    int page = 0;
    int count = 0;

    if (currentState is SuppliersLoaded) {
      currentList = currentState.suppliers;
      query = currentState.searchQuery;
      page = currentState.currentPage;
      count = currentState.totalCount;
    } else if (currentState is SuppliersError) {
      currentList = currentState.currentSuppliers;
      query = currentState.searchQuery;
      page = currentState.currentPage;
      count = currentState.totalCount;
    } else if (currentState is SupplierSaveError) {
      currentList = currentState.currentSuppliers;
      query = currentState.searchQuery;
      page = currentState.currentPage;
      count = currentState.totalCount;
    } else {
      return; // Cannot save if not loaded
    }

    emit(
      SupplierSaving(
        currentSuppliers: currentList,
        searchQuery: query,
        currentPage: page,
        totalCount: count,
      ),
    );

    final result = await saveSupplierUseCase(supplier);

    result.fold(
      (failure) {
        emit(
          SupplierSaveError(
            currentSuppliers: currentList,
            searchQuery: query,
            currentPage: page,
            totalCount: count,
            message: failure.message,
          ),
        );
      },
      (savedSupplier) {
        List<SupplierEntity> updatedList = List.from(currentList);

        final index = updatedList.indexWhere((s) => s.id == savedSupplier.id);
        if (index >= 0) {
          // Update existing
          updatedList[index] = savedSupplier;
        } else {
          // Add new (at the top)
          updatedList.insert(0, savedSupplier);
          count++;
        }

        emit(
          SupplierSaveSuccess(
            currentSuppliers: updatedList,
            searchQuery: query,
            currentPage: page,
            totalCount: count,
            message:
                supplier.id.isEmpty
                    ? 'Proveedor creado'
                    : 'Proveedor actualizado',
          ),
        );

        // Immediately transition back to loaded
        emit(
          SuppliersLoaded(
            suppliers: updatedList,
            searchQuery: query,
            currentPage: page,
            totalCount: count,
          ),
        );
      },
    );
  }

  void clearError() {
    final currentState = state;
    if (currentState is SuppliersError) {
      emit(
        SuppliersLoaded(
          suppliers: currentState.currentSuppliers,
          searchQuery: currentState.searchQuery,
          currentPage: currentState.currentPage,
          totalCount: currentState.totalCount,
        ),
      );
    }
  }
}
