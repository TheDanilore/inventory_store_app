import 'package:equatable/equatable.dart';

abstract class PurchaseOrdersState extends Equatable {
  static const int pageSize = 15;
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
  final int pageSize;

  const PurchaseOrdersLoading({
    this.currentOrders = const [],
    this.searchText = '',
    this.statusFilter = 'Todos',
    this.startDate,
    this.endDate,
    this.currentPage = 0,
    this.totalCount = 0,
    this.pageSize = PurchaseOrdersState.pageSize,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();

  @override
  List<Object?> get props => [
    currentOrders,
    searchText,
    statusFilter,
    startDate,
    endDate,
    currentPage,
    totalCount,
    pageSize,
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
  final int pageSize;

  const PurchaseOrdersLoaded({
    required this.orders,
    required this.searchText,
    required this.statusFilter,
    this.startDate,
    this.endDate,
    required this.currentPage,
    required this.totalCount,
    this.pageSize = PurchaseOrdersState.pageSize,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();

  PurchaseOrdersLoaded copyWith({
    List<dynamic>? orders,
    String? searchText,
    String? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? currentPage,
    int? totalCount,
    int? pageSize,
  }) {
    return PurchaseOrdersLoaded(
      orders: orders ?? this.orders,
      searchText: searchText ?? this.searchText,
      statusFilter: statusFilter ?? this.statusFilter,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      pageSize: pageSize ?? this.pageSize,
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
    pageSize,
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
  final int pageSize;

  const PurchaseOrdersError({
    required this.message,
    this.currentOrders = const [],
    this.searchText = '',
    this.statusFilter = 'Todos',
    this.startDate,
    this.endDate,
    this.currentPage = 0,
    this.totalCount = 0,
    this.pageSize = PurchaseOrdersState.pageSize,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();

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
    pageSize,
  ];
}

// ── Estados de operación puntual (pago / cambio de método) ──────────────────
// No interrumpen la lista paginada, solo señalizan al Sheet.

class PurchaseOrderActionLoading extends PurchaseOrdersState {}

class PurchaseOrderActionSuccess extends PurchaseOrdersState {
  final String message;
  final String orderId;

  /// Nuevo monto abonado (para mutación de caché de pago).
  final double? newAmountPaid;

  /// Nuevo método de pago (para mutación de caché de método).
  final String? newPaymentMethod;

  const PurchaseOrderActionSuccess({
    required this.message,
    required this.orderId,
    this.newAmountPaid,
    this.newPaymentMethod,
  });

  @override
  List<Object?> get props => [
    message,
    orderId,
    newAmountPaid,
    newPaymentMethod,
  ];
}

class PurchaseOrderActionError extends PurchaseOrdersState {
  final String message;

  const PurchaseOrderActionError({required this.message});

  @override
  List<Object?> get props => [message];
}
