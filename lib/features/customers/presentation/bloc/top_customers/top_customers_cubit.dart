import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_state.dart';

@lazySingleton
class TopCustomersCubit extends Cubit<TopCustomersState> {
  final GetTopCustomersUseCase _getTopCustomersUseCase;

  TopCustomersCubit(this._getTopCustomersUseCase)
    : super(TopCustomersInitial());

  Future<void> loadTopCustomers([int limit = 5, bool silent = false]) async {
    // Si ya contamos con top clientes previos en memoria, no forzamos Shimmer en la UI
    if (state is! TopCustomersLoaded && !silent) {
      emit(TopCustomersLoading());
    }
    try {
      final top = await _getTopCustomersUseCase(limit);
      emit(TopCustomersLoaded(top));
    } catch (e) {
      if (state is! TopCustomersLoaded) {
        emit(TopCustomersError(e.toString()));
      }
    }
  }
}
