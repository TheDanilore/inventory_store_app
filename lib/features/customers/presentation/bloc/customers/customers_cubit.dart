import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/export_customers_pdf_usecase.dart';

@injectable
class CustomersCubit extends Cubit<CustomersState> {
  final GetCustomersUseCase _getCustomersUseCase;
  final ExportCustomersPdfUseCase _exportPdfUseCase;

  static const int _limit = 20;
  Timer? _searchTimer;

  CustomersCubit(this._getCustomersUseCase, this._exportPdfUseCase)
    : super(CustomersInitial());

  Future<void> fetchCustomers({
    bool reset = false,
    String? query,
    bool? showOnlyWithDebt,
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
      currentCustomers = [];
      emit(CustomersLoading());
    } else {
      if (currentState is CustomersLoaded && currentState.hasReachedMax) return;
    }

    try {
      final newCustomers = await _getCustomersUseCase(
        limit: _limit,
        offset: currentCustomers.length,
        query: currentQuery,
        showOnlyWithDebt: currentDebtFilter,
      );

      emit(
        CustomersLoaded(
          customers:
              reset ? newCustomers : [...currentCustomers, ...newCustomers],
          hasReachedMax: newCustomers.length < _limit,
          query: currentQuery,
          showOnlyWithDebt: currentDebtFilter,
        ),
      );
    } catch (e) {
      emit(CustomersError('Error al cargar clientes: $e'));
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

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    return super.close();
  }
}
