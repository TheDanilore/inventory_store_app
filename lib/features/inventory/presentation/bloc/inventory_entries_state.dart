import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_model.dart';

abstract class InventoryEntriesState extends Equatable {
  const InventoryEntriesState();

  @override
  List<Object?> get props => [];
}

class InventoryEntriesInitial extends InventoryEntriesState {}

class InventoryEntriesLoading extends InventoryEntriesState {}

class InventoryEntriesLoaded extends InventoryEntriesState {
  final List<InventoryEntryModel> entries;
  final String searchQuery;
  final String warehouseFilter;
  final DateTimeRange? dateRange;
  final List<String> availableWarehouses;
  final int currentPage;
  final int totalCount;
  final int totalPages;

  const InventoryEntriesLoaded({
    required this.entries,
    required this.searchQuery,
    required this.warehouseFilter,
    this.dateRange,
    required this.availableWarehouses,
    required this.currentPage,
    required this.totalCount,
    required this.totalPages,
  });

  InventoryEntriesLoaded copyWith({
    List<InventoryEntryModel>? entries,
    String? searchQuery,
    String? warehouseFilter,
    DateTimeRange? dateRange,
    List<String>? availableWarehouses,
    int? currentPage,
    int? totalCount,
    int? totalPages,
    bool clearDateRange = false,
  }) {
    return InventoryEntriesLoaded(
      entries: entries ?? this.entries,
      searchQuery: searchQuery ?? this.searchQuery,
      warehouseFilter: warehouseFilter ?? this.warehouseFilter,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      availableWarehouses: availableWarehouses ?? this.availableWarehouses,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  @override
  List<Object?> get props => [
    entries,
    searchQuery,
    warehouseFilter,
    dateRange,
    availableWarehouses,
    currentPage,
    totalCount,
    totalPages,
  ];
}

class InventoryEntriesError extends InventoryEntriesState {
  final String message;

  const InventoryEntriesError(this.message);

  @override
  List<Object?> get props => [message];
}
