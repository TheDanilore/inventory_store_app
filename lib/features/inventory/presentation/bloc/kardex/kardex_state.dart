import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

abstract class KardexState extends Equatable {
  const KardexState();

  @override
  List<Object?> get props => [];
}

class KardexInitial extends KardexState {}

class KardexLoading extends KardexState {}

class KardexLoaded extends KardexState {
  final List<KardexMovementEntity> movements;
  final DateTime? startDate;
  final DateTime? endDate;
  final String typeFilter;
  final String searchText;
  final String? productId;
  final String? variantId;
  final String? variantName;
  final String? batchId;
  final String? batchNumber;
  final int currentPage;
  final int totalCount;
  final int totalPages;
  final bool isExporting;
  final bool isSearching;

  const KardexLoaded({
    required this.movements,
    this.startDate,
    this.endDate,
    required this.typeFilter,
    required this.searchText,
    this.productId,
    this.variantId,
    this.variantName,
    this.batchId,
    this.batchNumber,
    required this.currentPage,
    required this.totalCount,
    required this.totalPages,
    required this.isExporting,
    this.isSearching = false,
  });

  KardexLoaded copyWith({
    List<KardexMovementEntity>? movements,
    DateTime? startDate,
    DateTime? endDate,
    String? typeFilter,
    String? searchText,
    String? productId,
    String? variantId,
    String? variantName,
    String? batchId,
    String? batchNumber,
    bool clearProductId = false,
    bool clearVariantId = false,
    bool clearBatchId = false,
    int? currentPage,
    int? totalCount,
    int? totalPages,
    bool? isExporting,
    bool? isSearching,
    bool clearDateRange = false,
  }) {
    return KardexLoaded(
      movements: movements ?? this.movements,
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      typeFilter: typeFilter ?? this.typeFilter,
      searchText: searchText ?? this.searchText,
      productId: clearProductId ? null : (productId ?? this.productId),
      variantId: (clearProductId || clearVariantId) ? null : (variantId ?? this.variantId),
      variantName: (clearProductId || clearVariantId) ? null : (variantName ?? this.variantName),
      batchId: (clearProductId || clearVariantId || clearBatchId) ? null : (batchId ?? this.batchId),
      batchNumber: (clearProductId || clearVariantId || clearBatchId) ? null : (batchNumber ?? this.batchNumber),
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      isExporting: isExporting ?? this.isExporting,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object?> get props => [
    movements,
    startDate,
    endDate,
    typeFilter,
    searchText,
    productId,
    variantId,
    variantName,
    batchId,
    batchNumber,
    currentPage,
    totalCount,
    totalPages,
    isExporting,
    isSearching,
  ];
}

class KardexError extends KardexState {
  final String message;

  const KardexError(this.message);

  @override
  List<Object?> get props => [message];
}
