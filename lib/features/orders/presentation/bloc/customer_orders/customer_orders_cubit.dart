import 'dart:async';
import 'dart:developer' as developer;
import 'package:fpdart/fpdart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_customer_orders_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_order_items_uc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/customer_orders/customer_orders_state.dart';
import 'package:injectable/injectable.dart';

@injectable
class CustomerOrdersCubit extends Cubit<CustomerOrdersState> {
  final GetCustomerOrdersUc getCustomerOrdersUc;
  final GetOrderItemsUc getOrderItemsUc;
  static const int _limit = 15;

  StreamSubscription<AuthState>? _authSub;

  CustomerOrdersCubit({
    required this.getCustomerOrdersUc,
    required this.getOrderItemsUc,
  }) : super(const CustomerOrdersState()) {
    _initAuthListener();
  }

  void _initAuthListener() {
    final supabase = Supabase.instance.client;
    _init(supabase.auth.currentUser?.id);

    _authSub = supabase.auth.onAuthStateChange.listen((event) {
      if (isClosed) return;
      if (event.event == AuthChangeEvent.signedIn || event.event == AuthChangeEvent.tokenRefreshed) {
        _init(event.session?.user.id);
      } else if (event.event == AuthChangeEvent.signedOut) {
        _clear();
      }
    });
  }

  void _init(String? profileId) {
    if (profileId == null) {
      _clear();
      return;
    }
    if (state.orders.isNotEmpty && state.profileId == profileId) {
      return;
    }
    emit(
      state.copyWith(profileId: profileId, isLoading: true, errorMessage: ''),
    );
    _itemsCache.clear();
    _loadData(profileId);
  }

  void _clear() {
    _itemsCache.clear();
    emit(state.copyWith(
      profileId: null, 
      orders: [], 
      isLoading: false, 
      hasMore: false,
      errorMessage: ''
    ));
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }

  void setStatusFilter(String filter) {
    emit(state.copyWith(statusFilter: filter));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  final Map<String, List<OrderItemEntity>> _itemsCache = {};

  Future<Either<Failure, List<OrderItemEntity>>> fetchOrderItems(String orderId) async {
    if (_itemsCache.containsKey(orderId)) {
      return Right(_itemsCache[orderId]!);
    }
    final result = await getOrderItemsUc(orderId);
    return result.fold(
      (failure) {
        developer.log('Error fetching order items', error: failure.message);
        return Left(failure);
      }, 
      (items) {
        _itemsCache[orderId] = items;
        return Right(items);
      }
    );
  }

  Future<void> _loadData(String profileId) async {
    final result = await getCustomerOrdersUc(
      profileId,
      limit: _limit,
      offset: 0,
    );

    result.fold(
      (failure) {
        developer.log('Error en _loadData CustomerOrders', error: failure.message);
        emit(state.copyWith(isLoading: false, errorMessage: failure.message));
      },
      (orders) {
        emit(
          state.copyWith(
            isLoading: false,
            orders: orders,
            hasMore: orders.length == _limit,
            errorMessage: '',
          ),
        );
      },
    );
  }

  Future<void> refresh() async {
    if (state.profileId == null) return;
    emit(state.copyWith(isBackgroundLoading: true));

    final result = await getCustomerOrdersUc(
      state.profileId!,
      limit: _limit,
      offset: 0,
    );

    result.fold(
      (failure) {
        developer.log('Error en refresh CustomerOrders', error: failure.message);
        emit(state.copyWith(isBackgroundLoading: false));
      }, 
      (orders) {
        _itemsCache.clear();
        emit(
          state.copyWith(
            isBackgroundLoading: false,
            orders: orders,
            hasMore: orders.length == _limit,
          ),
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.profileId == null || state.isLoadingMore || !state.hasMore) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final result = await getCustomerOrdersUc(
      state.profileId!,
      limit: _limit,
      offset: state.orders.length,
    );

    result.fold(
      (failure) {
        developer.log('Error en loadMore CustomerOrders', error: failure.message);
        emit(state.copyWith(isLoadingMore: false, errorMessage: failure.message));
      },
      (newOrders) {
        emit(
          state.copyWith(
            isLoadingMore: false,
            orders: [...state.orders, ...newOrders],
            hasMore: newOrders.length == _limit,
          ),
        );
      },
    );
  }
}
