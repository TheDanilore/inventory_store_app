import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/bulk_toggle_suppliers_status_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_suppliers_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/save_supplier_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/toggle_supplier_status_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';

@injectable
class SuppliersCubit extends Cubit<SuppliersState> {
  final FetchSuppliersUseCase fetchSuppliersUseCase;
  final ToggleSupplierStatusUseCase toggleSupplierStatusUseCase;
  final BulkToggleSuppliersStatusUseCase bulkToggleSuppliersStatusUseCase;
  final SaveSupplierUseCase saveSupplierUseCase;

  static const int pageSize = SuppliersState.defaultPageSize;

  int _loadRequestId = 0;
  Timer? _searchDebounce;

  SuppliersCubit({
    required this.fetchSuppliersUseCase,
    required this.toggleSupplierStatusUseCase,
    required this.bulkToggleSuppliersStatusUseCase,
    required this.saveSupplierUseCase,
  }) : super(_buildInitialState(fetchSuppliersUseCase)) {
    if (state.status == SuppliersLoadStatus.coldLoading) {
      loadSuppliers();
    } else if (state.isRevalidating) {
      loadSuppliers(forceRefresh: true, silent: true);
    }
  }

  static SuppliersState _buildInitialState(FetchSuppliersUseCase fetchUseCase) {
    final snapshot = fetchUseCase.getLatestSnapshot();
    if (snapshot != null) {
      return SuppliersState(
        status: SuppliersLoadStatus.loaded,
        suppliers: snapshot.data.suppliers,
        stats: snapshot.data.stats ?? const SupplierStatsEntity.empty(),
        searchQuery: snapshot.searchQuery,
        filterIsActive: snapshot.filterIsActive,
        currentPage: snapshot.page,
        pageSize: snapshot.pageSize,
        totalCount: snapshot.data.totalCount,
        isFromCache: true,
        isRevalidating: snapshot.isStale,
      );
    }
    return const SuppliersState(status: SuppliersLoadStatus.coldLoading);
  }

  String formatFailureMessage(Failure failure, {required String fallback}) {
    return switch (failure) {
      NetworkFailure() => failure.message,
      UnauthorizedFailure() => failure.message,
      ValidationFailure() => failure.message,
      NotFoundFailure() => failure.message,
      ServerFailure() =>
        failure.message.isNotEmpty ? failure.message : fallback,
      CacheFailure() => failure.message,
      StockFailure() => failure.message,
      UnexpectedFailure() => fallback,
    };
  }

  Future<void> loadSuppliers({
    String? searchQuery,
    bool? filterIsActive,
    bool updateFilter = false,
    int? page,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    final nextQuery = (searchQuery ?? state.searchQuery).trim();
    final nextFilter = updateFilter ? filterIsActive : state.filterIsActive;
    final nextPage = page ?? state.currentPage;

    if (!forceRefresh) {
      final cached = fetchSuppliersUseCase.getCachedPage(
        page: nextPage,
        pageSize: state.pageSize,
        searchQuery: nextQuery,
        filterIsActive: nextFilter,
      );

      if (cached != null) {
        emit(
          state.copyWith(
            status: SuppliersLoadStatus.loaded,
            suppliers: cached.data.suppliers,
            stats: cached.data.stats ?? state.stats,
            searchQuery: nextQuery,
            filterIsActive: nextFilter,
            clearFilterIsActive: nextFilter == null,
            currentPage: nextPage,
            totalCount: cached.data.totalCount,
            isFromCache: true,
            isRevalidating: cached.isStale,
            clearLoadFailure: true,
          ),
        );

        if (!cached.isStale) {
          return;
        }
        silent = true;
      }
    }

    final requestId = ++_loadRequestId;
    final hasVisibleData = state.suppliers.isNotEmpty;

    emit(
      state.copyWith(
        status:
            hasVisibleData
                ? SuppliersLoadStatus.loaded
                : SuppliersLoadStatus.coldLoading,
        searchQuery: nextQuery,
        filterIsActive: nextFilter,
        clearFilterIsActive: nextFilter == null,
        currentPage: nextPage,
        isRevalidating: hasVisibleData || silent,
        clearLoadFailure: true,
      ),
    );

    final result = await fetchSuppliersUseCase(
      page: nextPage,
      pageSize: state.pageSize,
      searchQuery: nextQuery,
      filterIsActive: nextFilter,
      forceRefresh: forceRefresh,
    );

    if (isClosed || requestId != _loadRequestId) return;

    result.fold(
      (failure) {
        if (state.suppliers.isNotEmpty) {
          emit(
            state.copyWith(
              status: SuppliersLoadStatus.loaded,
              isRevalidating: false,
              loadFailure: failure,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: SuppliersLoadStatus.error,
              isRevalidating: false,
              loadFailure: failure,
            ),
          );
        }
      },
      (data) {
        emit(
          state.copyWith(
            status: SuppliersLoadStatus.loaded,
            suppliers: data.suppliers,
            stats: data.stats ?? state.stats,
            searchQuery: nextQuery,
            filterIsActive: nextFilter,
            clearFilterIsActive: nextFilter == null,
            currentPage: nextPage,
            totalCount: data.totalCount,
            isRevalidating: false,
            isFromCache: false,
            clearLoadFailure: true,
          ),
        );
      },
    );
  }

  void setSearchQueryDebounced(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!isClosed) {
        setSearchQuery(query);
      }
    });
  }

  void setSearchQuery(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed == state.searchQuery &&
        state.status == SuppliersLoadStatus.loaded &&
        !state.isRevalidating) {
      return;
    }
    loadSuppliers(searchQuery: trimmed, page: 0);
  }

  void setFilterIsActive(bool? filter) {
    if (filter == state.filterIsActive &&
        state.status == SuppliersLoadStatus.loaded) {
      return;
    }
    loadSuppliers(filterIsActive: filter, updateFilter: true, page: 0);
  }

  void setPage(int page) {
    if (page < 0 || page == state.currentPage) return;
    loadSuppliers(page: page);
  }

  void clearFilters() {
    _searchDebounce?.cancel();
    loadSuppliers(
      searchQuery: '',
      filterIsActive: null,
      updateFilter: true,
      page: 0,
    );
  }

  Future<void> toggleSupplierStatus(SupplierEntity supplier) async {
    if (state.mutationStatus == SupplierMutationStatus.submitting) return;

    emit(
      state.copyWith(
        mutationStatus: SupplierMutationStatus.submitting,
        mutationKind: SupplierMutationKind.toggle,
        clearMutationMessage: true,
        clearMutationFailure: true,
      ),
    );

    final result = await toggleSupplierStatusUseCase(
      supplier.id,
      supplier.isActive,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            mutationStatus: SupplierMutationStatus.failure,
            mutationKind: SupplierMutationKind.toggle,
            mutationMessage: formatFailureMessage(
              failure,
              fallback: 'Error al cambiar estado del proveedor.',
            ),
            mutationFailure: failure,
          ),
        );
      },
      (updatedFromServer) {
        final patched =
            updatedFromServer ?? supplier.copyWith(isActive: !supplier.isActive);
        final updatedList = _replaceSuppliersInList(state.suppliers, [patched]);

        emit(
          state.copyWith(
            suppliers: updatedList,
            mutationStatus: SupplierMutationStatus.success,
            mutationKind: SupplierMutationKind.toggle,
            mutationMessage:
                patched.isActive
                    ? 'Proveedor activado.'
                    : 'Proveedor desactivado.',
            clearMutationFailure: true,
          ),
        );

        loadSuppliers(forceRefresh: true, silent: true);
      },
    );
  }

  Future<void> bulkToggleSuppliersStatus(
    List<SupplierEntity> selectedSuppliers,
  ) async {
    if (selectedSuppliers.isEmpty ||
        state.mutationStatus == SupplierMutationStatus.submitting) {
      return;
    }

    emit(
      state.copyWith(
        mutationStatus: SupplierMutationStatus.submitting,
        mutationKind: SupplierMutationKind.bulkToggle,
        clearMutationMessage: true,
        clearMutationFailure: true,
      ),
    );

    final ids = selectedSuppliers.map((s) => s.id).toList(growable: false);
    final result = await bulkToggleSuppliersStatusUseCase(ids);

    if (isClosed) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            mutationStatus: SupplierMutationStatus.failure,
            mutationKind: SupplierMutationKind.bulkToggle,
            mutationMessage: formatFailureMessage(
              failure,
              fallback: 'Error al actualizar el estado masivo de proveedores.',
            ),
            mutationFailure: failure,
          ),
        );
      },
      (updatedFromServer) {
        final updatedList = _replaceSuppliersInList(
          state.suppliers,
          updatedFromServer,
        );
        emit(
          state.copyWith(
            suppliers: updatedList,
            mutationStatus: SupplierMutationStatus.success,
            mutationKind: SupplierMutationKind.bulkToggle,
            mutationMessage:
                'Se actualizó el estado de ${updatedFromServer.length} proveedores.',
            clearMutationFailure: true,
          ),
        );

        loadSuppliers(forceRefresh: true, silent: true);
      },
    );
  }

  Future<void> saveSupplier(SupplierEntity supplier) async {
    if (state.mutationStatus == SupplierMutationStatus.submitting) return;

    emit(
      state.copyWith(
        mutationStatus: SupplierMutationStatus.submitting,
        mutationKind: SupplierMutationKind.save,
        clearMutationMessage: true,
        clearMutationFailure: true,
      ),
    );

    final result = await saveSupplierUseCase(supplier);

    if (isClosed) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            mutationStatus: SupplierMutationStatus.failure,
            mutationKind: SupplierMutationKind.save,
            mutationMessage: formatFailureMessage(
              failure,
              fallback: 'Error al guardar el proveedor.',
            ),
            mutationFailure: failure,
          ),
        );
      },
      (savedSupplier) {
        final isNew = supplier.id.isEmpty;
        final updatedList =
            isNew
                ? state.suppliers
                : _replaceSuppliersInList(state.suppliers, [savedSupplier]);

        emit(
          state.copyWith(
            suppliers: updatedList,
            mutationStatus: SupplierMutationStatus.success,
            mutationKind: SupplierMutationKind.save,
            mutationMessage:
                isNew ? 'Proveedor creado' : 'Proveedor actualizado',
            clearMutationFailure: true,
          ),
        );

        loadSuppliers(forceRefresh: true, silent: true);
      },
    );
  }

  List<SupplierEntity> _replaceSuppliersInList(
    List<SupplierEntity> source,
    List<SupplierEntity> updates,
  ) {
    if (updates.isEmpty) return source;
    final byId = {for (final s in updates) s.id: s};
    var changed = false;
    final next = List<SupplierEntity>.from(source);
    for (var i = 0; i < next.length; i++) {
      final match = byId[next[i].id];
      if (match != null) {
        next[i] = match;
        changed = true;
      }
    }
    return changed ? List.unmodifiable(next) : source;
  }

  void clearLoadFailure() {
    if (state.loadFailure != null) {
      emit(state.copyWith(clearLoadFailure: true));
    }
  }

  void clearMutationFeedback() {
    if (state.mutationStatus != SupplierMutationStatus.idle ||
        state.mutationKind != SupplierMutationKind.none ||
        state.mutationMessage != null ||
        state.mutationFailure != null) {
      emit(
        state.copyWith(
          mutationStatus: SupplierMutationStatus.idle,
          mutationKind: SupplierMutationKind.none,
          clearMutationMessage: true,
          clearMutationFailure: true,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
