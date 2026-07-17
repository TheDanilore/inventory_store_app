import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';

class CashShiftsState extends Equatable {
  final List<CashShiftEntity> shifts;
  final Set<String> openAccountIds;
  final bool isLoading;
  final String errorMessage;
  final int currentPage;
  final int totalCount;
  final int totalOpenCount;
  final int totalClosedCount;
  final String filterStatus;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? profileFilter;

  const CashShiftsState({
    this.shifts = const [],
    this.openAccountIds = const {},
    this.isLoading = false,
    this.errorMessage = '',
    this.currentPage = 0,
    this.totalCount = 0,
    this.totalOpenCount = 0,
    this.totalClosedCount = 0,
    this.filterStatus = 'Todos',
    this.dateFrom,
    this.dateTo,
    this.profileFilter,
  });

  CashShiftsState copyWith({
    List<CashShiftEntity>? shifts,
    Set<String>? openAccountIds,
    bool? isLoading,
    String? errorMessage,
    int? currentPage,
    int? totalCount,
    int? totalOpenCount,
    int? totalClosedCount,
    String? filterStatus,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? profileFilter,
    bool clearDates = false,
    bool clearProfileFilter = false,
  }) {
    return CashShiftsState(
      shifts: shifts ?? this.shifts,
      openAccountIds: openAccountIds ?? this.openAccountIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      totalOpenCount: totalOpenCount ?? this.totalOpenCount,
      totalClosedCount: totalClosedCount ?? this.totalClosedCount,
      filterStatus: filterStatus ?? this.filterStatus,
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      profileFilter: clearProfileFilter ? null : (profileFilter ?? this.profileFilter),
    );
  }

  int get pageSize => 15;
  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
  int get openCount => shifts.where((s) => s.status == CashShiftStatus.open).length;

  @override
  List<Object?> get props => [
        shifts,
        openAccountIds,
        isLoading,
        errorMessage,
        currentPage,
        totalCount,
        totalOpenCount,
        totalClosedCount,
        filterStatus,
        dateFrom,
        dateTo,
        profileFilter,
      ];
}
