import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

sealed class CustomersState extends Equatable {
  const CustomersState();

  @override
  List<Object?> get props => [];
}

class CustomersInitial extends CustomersState {}

class CustomersLoading extends CustomersState {}

class CustomersLoaded extends CustomersState {
  final List<CustomerEntity> customers;
  final bool hasReachedMax;
  final int totalCount;
  final String query;
  final bool showOnlyWithDebt;
  final int activeTabIndex;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isExportingPdf;
  final bool isFromCache;
  final String? transientErrorMessage;

  const CustomersLoaded({
    required this.customers,
    required this.hasReachedMax,
    this.totalCount = 0,
    this.query = '',
    this.showOnlyWithDebt = false,
    this.activeTabIndex = 0,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isExportingPdf = false,
    this.isFromCache = false,
    this.transientErrorMessage,
  });

  bool get hasCustomers => customers.isNotEmpty;

  CustomersLoaded copyWith({
    List<CustomerEntity>? customers,
    bool? hasReachedMax,
    int? totalCount,
    String? query,
    bool? showOnlyWithDebt,
    int? activeTabIndex,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isExportingPdf,
    bool? isFromCache,
    String? transientErrorMessage,
    bool clearTransientError = false,
  }) {
    return CustomersLoaded(
      customers: customers ?? this.customers,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      totalCount: totalCount ?? this.totalCount,
      query: query ?? this.query,
      showOnlyWithDebt: showOnlyWithDebt ?? this.showOnlyWithDebt,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isExportingPdf: isExportingPdf ?? this.isExportingPdf,
      isFromCache: isFromCache ?? this.isFromCache,
      transientErrorMessage:
          clearTransientError
              ? null
              : (transientErrorMessage ?? this.transientErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
    customers,
    hasReachedMax,
    totalCount,
    query,
    showOnlyWithDebt,
    activeTabIndex,
    isRefreshing,
    isLoadingMore,
    isExportingPdf,
    isFromCache,
    transientErrorMessage,
  ];
}

class CustomersError extends CustomersState {
  final Failure failure;

  const CustomersError(this.failure);

  String get message => failure.message;

  @override
  List<Object?> get props => [failure];
}
