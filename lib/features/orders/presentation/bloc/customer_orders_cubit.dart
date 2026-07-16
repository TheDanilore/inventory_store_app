import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_customer_orders_uc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/customer_orders_state.dart';

import 'package:injectable/injectable.dart';

@injectable
class CustomerOrdersCubit extends Cubit<CustomerOrdersState> {
  final GetCustomerOrdersUc getCustomerOrdersUc;
  static const int _limit = 15;

  CustomerOrdersCubit({
    required this.getCustomerOrdersUc,
  }) : super(const CustomerOrdersState());

  void init(String? profileId) {
    if (profileId == null) {
      emit(state.copyWith(isLoading: false));
      return;
    }
    emit(state.copyWith(profileId: profileId, isLoading: true, errorMessage: ''));
    _loadData(profileId);
  }

  Future<void> _loadData(String profileId) async {
    final result = await getCustomerOrdersUc(profileId, limit: _limit, offset: 0);

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, errorMessage: failure.message)),
      (orders) {
        emit(state.copyWith(
          isLoading: false,
          orders: orders,
          hasMore: orders.length == _limit,
          errorMessage: '',
        ));
      },
    );
  }

  Future<void> refresh() async {
    if (state.profileId == null) return;
    emit(state.copyWith(isBackgroundLoading: true));
    
    final result = await getCustomerOrdersUc(state.profileId!, limit: _limit, offset: 0);

    result.fold(
      (failure) => emit(state.copyWith(isBackgroundLoading: false)),
      (orders) {
        emit(state.copyWith(
          isBackgroundLoading: false,
          orders: orders,
          hasMore: orders.length == _limit,
        ));
      },
    );
  }

  Future<void> loadMore() async {
    if (state.profileId == null || state.isLoadingMore || !state.hasMore) return;
    
    emit(state.copyWith(isLoadingMore: true));
    
    final result = await getCustomerOrdersUc(state.profileId!, limit: _limit, offset: state.orders.length);

    result.fold(
      (failure) => emit(state.copyWith(isLoadingMore: false, errorMessage: failure.message)),
      (newOrders) {
        emit(state.copyWith(
          isLoadingMore: false,
          orders: [...state.orders, ...newOrders],
          hasMore: newOrders.length == _limit,
        ));
      },
    );
  }
}
