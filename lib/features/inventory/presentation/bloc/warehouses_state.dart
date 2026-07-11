import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';

class WarehousesState extends Equatable {
  final List<WarehouseModel> warehouses;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  
  final String searchQuery;
  final int currentPage;
  final int totalRecords;
  final int pageSize;

  const WarehousesState({
    this.warehouses = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.searchQuery = '',
    this.currentPage = 0,
    this.totalRecords = 0,
    this.pageSize = 8,
  });

  int get totalPages {
    if (totalRecords == 0) return 1;
    return (totalRecords / pageSize).ceil();
  }

  WarehousesState copyWith({
    List<WarehouseModel>? warehouses,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
    String? searchQuery,
    int? currentPage,
    int? totalRecords,
  }) {
    return WarehousesState(
      warehouses: warehouses ?? this.warehouses,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      totalRecords: totalRecords ?? this.totalRecords,
      pageSize: pageSize,
    );
  }

  @override
  List<Object?> get props => [
        warehouses,
        isLoading,
        isSaving,
        errorMessage,
        successMessage,
        searchQuery,
        currentPage,
        totalRecords,
        pageSize,
      ];
}
