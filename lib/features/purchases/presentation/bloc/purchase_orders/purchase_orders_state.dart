import 'package:equatable/equatable.dart';

abstract class PurchaseOrdersState extends Equatable {
  const PurchaseOrdersState();

  @override
  List<Object?> get props => [];
}

class PurchaseOrdersInitial extends PurchaseOrdersState {}

class PurchaseOrdersLoading extends PurchaseOrdersState {
  final List<dynamic> currentOrders;
  final String searchText;
  final String statusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int currentPage;
  final int totalCount;

  const PurchaseOrdersLoading({
    this.currentOrders = const [],
    this.searchText = '',
    this.statusFilter = 'Todos',
    this.startDate,
    this.endDate,
    this.currentPage = 0,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [
        currentOrders,
        searchText,
        statusFilter,
        startDate,
        endDate,
        currentPage,
        totalCount,
      ];
}

class PurchaseOrdersLoaded extends PurchaseOrdersState {
  final List<dynamic> orders;
  final String searchText;
  final String statusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int currentPage;
  final int totalCount;

  const PurchaseOrdersLoaded({
    required this.orders,
    required this.searchText,
    required this.statusFilter,
    this.startDate,
    this.endDate,
    required this.currentPage,
    required this.totalCount,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / 10).ceil();

  PurchaseOrdersLoaded copyWith({
    List<dynamic>? orders,
    String? searchText,
    String? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? currentPage,
    int? totalCount,
  }) {
    return PurchaseOrdersLoaded(
      orders: orders ?? this.orders,
      searchText: searchText ?? this.searchText,
      statusFilter: statusFilter ?? this.statusFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [
        orders,
        searchText,
        statusFilter,
        startDate,
        endDate,
        currentPage,
        totalCount,
      ];
}

class PurchaseOrdersError extends PurchaseOrdersState {
  final String message;
  final List<dynamic> currentOrders;
  final String searchText;
  final String statusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final int currentPage;
  final int totalCount;

  const PurchaseOrdersError({
    required this.message,
    this.currentOrders = const [],
    this.searchText = '',
    this.statusFilter = 'Todos',
    this.startDate,
    this.endDate,
    this.currentPage = 0,
    this.totalCount = 0,
  });

  @override
  List<Object?> get props => [
        message,
        currentOrders,
        searchText,
        statusFilter,
        startDate,
        endDate,
        currentPage,
        totalCount,
      ];
}
