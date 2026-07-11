import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/kardex_movement_model.dart';

abstract class KardexState extends Equatable {
  const KardexState();

  @override
  List<Object?> get props => [];
}

class KardexInitial extends KardexState {}

class KardexLoading extends KardexState {}

class KardexLoaded extends KardexState {
  final List<KardexMovementModel> movements;
  final DateTimeRange? dateRange;
  final String typeFilter;
  final String searchText;
  final int currentPage;
  final int totalCount;
  final int totalPages;
  final bool isExporting;

  const KardexLoaded({
    required this.movements,
    this.dateRange,
    required this.typeFilter,
    required this.searchText,
    required this.currentPage,
    required this.totalCount,
    required this.totalPages,
    required this.isExporting,
  });

  KardexLoaded copyWith({
    List<KardexMovementModel>? movements,
    DateTimeRange? dateRange,
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
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
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
        dateRange,
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
