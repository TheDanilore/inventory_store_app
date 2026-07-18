import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

class CustomerOrdersState extends Equatable {
  final List<OrderEntity> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isBackgroundLoading;
  final String statusFilter;
  final String searchQuery;
  final String? profileId;
  final String errorMessage;

  const CustomerOrdersState({
    this.orders = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.isBackgroundLoading = false,
    this.statusFilter = 'ALL',
    this.searchQuery = '',
    this.profileId,
    this.errorMessage = '',
  });

  CustomerOrdersState copyWith({
    List<OrderEntity>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? isBackgroundLoading,
    String? statusFilter,
    String? searchQuery,
    String? profileId,
    String? errorMessage,
  }) {
    return CustomerOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      isBackgroundLoading: isBackgroundLoading ?? this.isBackgroundLoading,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      profileId: profileId ?? this.profileId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    orders,
    isLoading,
    isLoadingMore,
    hasMore,
    isBackgroundLoading,
    statusFilter,
    searchQuery,
    profileId,
    errorMessage,
  ];
}
