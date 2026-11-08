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
  final String warehouseFilter;
  final List<String> availableWarehouses;
  final DateTime? startDate;
  final DateTime? endDate;

  final double totalCost;
  final int totalUnits;

  const InventoryExitsState({
    this.exits = const [],
    this.isLoading = false,
    this.errorMessage,
    this.currentPage = 0,
    this.totalRecords = 0,
    this.pageSize = 15,
    this.searchQuery = '',
    this.warehouseFilter = 'Todos',
    this.availableWarehouses = const ['Todos'],
    this.startDate,
    this.endDate,
    this.totalCost = 0.0,
    this.totalUnits = 0,
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
    String? warehouseFilter,
    List<String>? availableWarehouses,
    DateTime? startDate,
    DateTime? endDate,
    double? totalCost,
    int? totalUnits,
    bool clearErrorMessage = false,
    bool clearDateRange = false,
  }) {
    final newExits = exits ?? this.exits;
    final newTotalCost = exits != null
        ? newExits.fold<double>(0.0, (s, e) => s + e.totalCost)
        : (totalCost ?? this.totalCost);
    final newTotalUnits = exits != null
        ? newExits.fold<int>(0, (s, e) => s + e.itemCount)
        : (totalUnits ?? this.totalUnits);

    return InventoryExitsState(
      exits: newExits,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      currentPage: currentPage ?? this.currentPage,
      totalRecords: totalRecords ?? this.totalRecords,
      pageSize: pageSize ?? this.pageSize,
      searchQuery: searchQuery ?? this.searchQuery,
      warehouseFilter: warehouseFilter ?? this.warehouseFilter,
      availableWarehouses: availableWarehouses ?? this.availableWarehouses,
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      totalCost: newTotalCost,
      totalUnits: newTotalUnits,
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
    warehouseFilter,
    availableWarehouses,
    startDate,
    endDate,
    totalCost,
    totalUnits,
  ];
}
