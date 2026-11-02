import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/export_customers_pdf_usecase.dart';

@lazySingleton
class CustomersCubit extends Cubit<CustomersState> {
  final GetCustomersUseCase _getCustomersUseCase;
  final ExportCustomersPdfUseCase _exportPdfUseCase;

  static const int _limit = 20;
  Timer? _searchTimer;

  /// Caché en memoria por modo de filtro (false = Todos, true = Con Deuda)
  /// para conmutación instantánea en Frame 0 con Zero-Shimmer.
  final Map<bool, List<CustomerEntity>> _filterCache = {};
  final Map<bool, bool> _filterReachedMax = {};

  CustomersCubit(this._getCustomersUseCase, this._exportPdfUseCase)
    : super(CustomersInitial());

  Future<void> fetchCustomers({
    bool reset = false,
    String? query,
    bool? showOnlyWithDebt,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final currentState = state;

    List<CustomerEntity> currentCustomers = [];
    String currentQuery = '';
    bool currentDebtFilter = false;

    if (currentState is CustomersLoaded) {
      currentCustomers = currentState.customers;
      currentQuery = query ?? currentState.query;
      currentDebtFilter = showOnlyWithDebt ?? currentState.showOnlyWithDebt;
    } else {
      currentQuery = query ?? '';
      currentDebtFilter = showOnlyWithDebt ?? false;
    }

    if (reset) {
      if (forceRefresh) {
        _filterCache.clear();
        _filterReachedMax.clear();
      }

      // Si tenemos datos cacheados para este filtro exacto en búsqueda vacía,
      // emitimos de inmediato en Frame 0 garantizando Cero Shimmer.
      if (currentQuery.isEmpty && _filterCache.containsKey(currentDebtFilter)) {
        final cached = _filterCache[currentDebtFilter]!;
        final reachedMax = _filterReachedMax[currentDebtFilter] ?? false;
        currentCustomers = cached;
        emit(
          CustomersLoaded(
            customers: cached,
            hasReachedMax: reachedMax,
            query: currentQuery,
            showOnlyWithDebt: currentDebtFilter,
            isRefreshing: !silent,
          ),
        );
      } else if (currentCustomers.isEmpty && !silent) {
        emit(CustomersLoading());
      } else if (currentState is CustomersLoaded) {
        emit(currentState.copyWith(isRefreshing: true));
      }
    } else {
      if (currentState is CustomersLoaded && currentState.hasReachedMax) return;
    }

    try {
      final offset = reset ? 0 : currentCustomers.length;
      final newCustomers = await _getCustomersUseCase(
        limit: _limit,
        offset: offset,
        query: currentQuery,
        showOnlyWithDebt: currentDebtFilter,
        forceRefresh: forceRefresh,
      );

      final updatedList =
          reset ? newCustomers : [...currentCustomers, ...newCustomers];
      final hasReachedMax = newCustomers.length < _limit;

      // Actualizar caché en memoria cuando no hay búsqueda activa
      if (currentQuery.isEmpty) {
        _filterCache[currentDebtFilter] = updatedList;
        _filterReachedMax[currentDebtFilter] = hasReachedMax;
      }

      emit(
        CustomersLoaded(
          customers: updatedList,
          hasReachedMax: hasReachedMax,
          query: currentQuery,
          showOnlyWithDebt: currentDebtFilter,
          isRefreshing: false,
        ),
      );
    } catch (e) {
      // Si ya hay clientes visibles, mantenemos los datos y no destruimos la UI con pantalla roja
      if (currentCustomers.isNotEmpty && currentState is CustomersLoaded) {
        emit(currentState.copyWith(isRefreshing: false));
      } else {
        final msg =
            e is AppException ? e.message : 'Error al cargar clientes: $e';
        emit(CustomersError(msg));
      }
    }
  }

  Future<void> exportPdf() async {
    if (state is CustomersLoaded) {
      await _exportPdfUseCase((state as CustomersLoaded).customers);
    }
  }

  void search(String query) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      fetchCustomers(reset: true, query: query);
    });
  }

  void toggleDebtFilter(bool showDebt) {
    _searchTimer?.cancel();
    fetchCustomers(reset: true, showOnlyWithDebt: showDebt);
  }

  void invalidateCache() {
    _filterCache.clear();
    _filterReachedMax.clear();
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
