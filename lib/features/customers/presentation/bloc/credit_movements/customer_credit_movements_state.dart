import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';

class CustomerCreditMovementsState extends Equatable {
  final String creditId;
  final String customerName;
  final double currentDebt;
  final double creditLimit;

  final bool isLoading;
  final bool isExporting;
  final List<CreditMovementEntity> movements;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  final double totalCharged;
  final double totalPaid;
  final String dateFilter;
  final String? error;
  final bool exportSuccess;

  const CustomerCreditMovementsState({
    required this.creditId,
    required this.customerName,
    required this.currentDebt,
    required this.creditLimit,
    this.isLoading = true,
    this.isExporting = false,
    this.movements = const [],
    this.totalCount = 0,
    this.currentPage = 0,
    this.pageSize = 8,
    this.totalCharged = 0.0,
    this.totalPaid = 0.0,
    this.dateFilter = 'all',
    this.error,
    this.exportSuccess = false,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  double get debtPercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;

  CustomerCreditMovementsState copyWith({
    String? creditId,
    String? customerName,
    double? currentDebt,
    double? creditLimit,
    bool? isLoading,
    bool? isExporting,
    List<CreditMovementEntity>? movements,
    int? totalCount,
    int? currentPage,
    int? pageSize,
    double? totalCharged,
    double? totalPaid,
    String? dateFilter,
    String? error,
    bool? exportSuccess,
  }) {
    return CustomerCreditMovementsState(
      creditId: creditId ?? this.creditId,
      customerName: customerName ?? this.customerName,
      currentDebt: currentDebt ?? this.currentDebt,
      creditLimit: creditLimit ?? this.creditLimit,
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      movements: movements ?? this.movements,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalCharged: totalCharged ?? this.totalCharged,
      totalPaid: totalPaid ?? this.totalPaid,
      dateFilter: dateFilter ?? this.dateFilter,
      error: error,
      exportSuccess:
          exportSuccess ?? false, // Reset by default unless explicitly true
    );
  }

  @override
  List<Object?> get props => [
    creditId,
    customerName,
    currentDebt,
    creditLimit,
    isLoading,
    isExporting,
    movements,
    totalCount,
    currentPage,
    pageSize,
    totalCharged,
    totalPaid,
    dateFilter,
    error,
    exportSuccess,
  ];
}
