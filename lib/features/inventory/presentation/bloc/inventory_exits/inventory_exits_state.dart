import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';

class InventoryExitsState extends Equatable {
  final List<InventoryExitEntity> exits;
  final bool isLoading;
  final String? errorMessage;

  final int currentPage;
  final int totalRecords;
  final int pageSize;

  final String searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;

  const InventoryExitsState({
    this.exits = const [],
    this.isLoading = false,
    this.errorMessage,
    this.currentPage = 0,
    this.totalRecords = 0,
    this.pageSize = 8,
    this.searchQuery = '',
    this.startDate,
    this.endDate,
  });

  int get totalPages =>
      totalRecords == 0 ? 1 : (totalRecords / pageSize).ceil();

  InventoryExitsState copyWith({
    List<InventoryExitEntity>? exits,
    bool? isLoading,
    String? errorMessage,
    int? currentPage,
    int? totalRecords,
    int? pageSize,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    bool clearErrorMessage = false,
    bool clearDateRange = false,
  }) {
    return InventoryExitsState(
      exits: exits ?? this.exits,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      totalRecords: totalRecords ?? this.totalRecords,
      pageSize: pageSize ?? this.pageSize,
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
    );
  }

  @override
  List<Object?> get props => [
    exits,
    isLoading,
    errorMessage,
    currentPage,
    totalRecords,
    pageSize,
    searchQuery,
    startDate,
    endDate,
  ];
}
