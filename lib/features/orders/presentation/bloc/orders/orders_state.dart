import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

class OrdersState extends Equatable {
  final List<OrderEntity> orders;
  final int totalRecords;
  final bool isLoading;
  final bool isBackgroundLoading;
  final String errorMessage;
  final Set<String> processingOrders;
  final String? generatingPdfOrderId;
  final String statusFilter;
  final String paymentStatusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;
  final int currentPage;
  final String? customerIdFilter;

  const OrdersState({
    this.orders = const [],
    this.totalRecords = 0,
    this.isLoading = false,
    this.isBackgroundLoading = false,
    this.errorMessage = '',
    this.processingOrders = const {},
    this.generatingPdfOrderId,
    this.statusFilter = 'ALL',
    this.paymentStatusFilter = 'ALL',
    this.startDate,
    this.endDate,
    this.searchQuery = '',
    this.currentPage = 0,
    this.customerIdFilter,
  });

  OrdersState copyWith({
    List<OrderEntity>? orders,
    int? totalRecords,
    bool? isLoading,
    bool? isBackgroundLoading,
    String? errorMessage,
    Set<String>? processingOrders,
    String? generatingPdfOrderId,
    bool clearPdfOrderId = false,
    String? statusFilter,
    String? paymentStatusFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    String? searchQuery,
    int? currentPage,
    String? customerIdFilter,
    bool clearCustomerId = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      totalRecords: totalRecords ?? this.totalRecords,
      isLoading: isLoading ?? this.isLoading,
      isBackgroundLoading: isBackgroundLoading ?? this.isBackgroundLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      processingOrders: processingOrders ?? this.processingOrders,
      generatingPdfOrderId:
          clearPdfOrderId
              ? null
              : (generatingPdfOrderId ?? this.generatingPdfOrderId),
      statusFilter: statusFilter ?? this.statusFilter,
      paymentStatusFilter: paymentStatusFilter ?? this.paymentStatusFilter,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      customerIdFilter:
          clearCustomerId ? null : (customerIdFilter ?? this.customerIdFilter),
    );
  }

  @override
  List<Object?> get props => [
    orders,
    totalRecords,
    isLoading,
    isBackgroundLoading,
    errorMessage,
    processingOrders,
    generatingPdfOrderId,
    statusFilter,
    paymentStatusFilter,
    startDate,
    endDate,
    searchQuery,
    currentPage,
    customerIdFilter,
  ];

  static const int pageSize = 24;

  int get totalPages =>
      totalRecords == 0 ? 1 : (totalRecords / pageSize).ceil();

  bool isOrderProcessing(String id) => processingOrders.contains(id);

  bool isGeneratingPDF(String id) => generatingPdfOrderId == id;

  double get totalAmountCurrentPage =>
      orders.fold<double>(0, (sum, order) => sum + order.totalAmount);

  int get pendingCountCurrentPage =>
      orders.where((o) => o.status == 'PENDING').length;

  double get pendingDebtCurrentPage => orders
      .where((o) => o.paymentStatus != 'PAID' && o.status != 'CANCELLED')
      .fold<double>(0, (sum, o) => sum + (o.totalAmount - o.amountPaid));
}
