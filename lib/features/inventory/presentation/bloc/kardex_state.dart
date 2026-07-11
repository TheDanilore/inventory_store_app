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
  final int currentPage;
  final int totalCount;
  final int totalPages;
  final bool isExporting;

  const KardexLoaded({
    required this.movements,
    this.startDate,
    this.endDate,
    required this.typeFilter,
    required this.searchText,
    required this.currentPage,
    required this.totalCount,
    required this.totalPages,
    required this.isExporting,
  });

  KardexLoaded copyWith({
    List<KardexMovementEntity>? movements,
    DateTime? startDate,
    DateTime? endDate,
    String? typeFilter,
    String? searchText,
    int? currentPage,
    int? totalCount,
    int? totalPages,
    bool? isExporting,
    bool clearDateRange = false,
  }) {
    return KardexLoaded(
      movements: movements ?? this.movements,
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      typeFilter: typeFilter ?? this.typeFilter,
      searchText: searchText ?? this.searchText,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      isExporting: isExporting ?? this.isExporting,
    );
  }

  @override
  List<Object?> get props => [
        movements,
        startDate,
        endDate,
        typeFilter,
        searchText,
        currentPage,
        totalCount,
        totalPages,
        isExporting,
      ];
}

class KardexError extends KardexState {
  final String message;

  const KardexError(this.message);

  @override
  List<Object?> get props => [message];
}
