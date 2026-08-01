import 'dart:async';
import 'dart:developer' as developer;
import 'package:fpdart/fpdart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
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

  CustomerOrdersCubit({
    required this.getCustomerOrdersUc,
    required this.getOrderItemsUc,
  }) : super(const CustomerOrdersState());

  void init(String profileId) {
    if (state.isLoading && state.profileId == profileId) return;
    if (state.orders.isNotEmpty && state.profileId == profileId) {
      return;
    }
    emit(
      state.copyWith(profileId: profileId, isLoading: true, errorMessage: ''),
    );
    _itemsCache.clear();
    _loadData(profileId);
  }

  List<OrderEntity> _applyFilters(List<OrderEntity> orders, String status, String query) {
    return orders.where((order) {
      final matchesStatus = status == 'ALL' || order.status == status;
      final matchesSearch = query.isEmpty ||
          order.id.toLowerCase().contains(query.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Future<void> close() {
    _itemsCache.clear();
    return super.close();
  }

  void setStatusFilter(String filter) {
    final newFiltered = _applyFilters(state.orders, filter, state.searchQuery);
    emit(state.copyWith(statusFilter: filter, filteredOrders: newFiltered));
  }

  void setSearchQuery(String query) {
    final newFiltered = _applyFilters(state.orders, state.statusFilter, query);
    emit(state.copyWith(searchQuery: query, filteredOrders: newFiltered));
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
        // Simple FIFO cache eviction policy to prevent memory leaks
        if (_itemsCache.length >= 20) {
          _itemsCache.remove(_itemsCache.keys.first);
        }
        _itemsCache[orderId] = items;
        return Right(items);
      }
    );
  }

  Future<void> _loadData(String profileId) async {
    final result = await getCustomerOrdersUc(
      profileId,
      limit: _limit,
    );

    result.fold(
      (failure) {
        developer.log('Error en _loadData CustomerOrders', error: failure.message);
        emit(state.copyWith(isLoading: false, errorMessage: failure.message));
      },
      (orders) {
        final newFiltered = _applyFilters(orders, state.statusFilter, state.searchQuery);
        emit(
          state.copyWith(
            isLoading: false,
            orders: orders,
            filteredOrders: newFiltered,
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
    );

    result.fold(
      (failure) {
        developer.log('Error en refresh CustomerOrders', error: failure.message);
        emit(state.copyWith(isBackgroundLoading: false));
      }, 
      (orders) {
        _itemsCache.clear();
        final newFiltered = _applyFilters(orders, state.statusFilter, state.searchQuery);
        emit(
          state.copyWith(
            isBackgroundLoading: false,
            orders: orders,
            filteredOrders: newFiltered,
            hasMore: orders.length == _limit,
          ),
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.profileId == null || state.isLoadingMore || !state.hasMore || state.orders.isEmpty) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    final lastOrder = state.orders.last;
    final result = await getCustomerOrdersUc(
      state.profileId!,
      limit: _limit,
      lastCreatedAt: lastOrder.createdAt,
    );

    result.fold(
      (failure) {
        developer.log('Error en loadMore CustomerOrders', error: failure.message);
        emit(state.copyWith(isLoadingMore: false, errorMessage: failure.message));
      },
      (newOrders) {
        final combinedOrders = [...state.orders, ...newOrders];
        final newFiltered = _applyFilters(combinedOrders, state.statusFilter, state.searchQuery);
        emit(
          state.copyWith(
            isLoadingMore: false,
            orders: combinedOrders,
            filteredOrders: newFiltered,
            hasMore: newOrders.length == _limit,
          ),
        );
      },
    );
  }
}
