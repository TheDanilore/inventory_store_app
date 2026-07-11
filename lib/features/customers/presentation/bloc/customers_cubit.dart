import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_ucs.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers_state.dart';

@injectable
class CustomersCubit extends Cubit<CustomersState> {
  final GetCustomersUseCase _getCustomersUseCase;

  static const int _limit = 20;

  CustomersCubit(this._getCustomersUseCase) : super(CustomersInitial());

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
      // Do not emit loading again to preserve the list
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
      emit(CustomersError(e.toString()));
    }
  }

  void search(String query) {
    fetchCustomers(reset: true, query: query);
  }

  void toggleDebtFilter(bool showDebt) {
    fetchCustomers(reset: true, showOnlyWithDebt: showDebt);
  }
}
