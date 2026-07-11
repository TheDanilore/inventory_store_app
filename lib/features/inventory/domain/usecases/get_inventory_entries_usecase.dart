import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';

@injectable
class GetInventoryEntriesUseCase {
  final InventoryEntriesRepository repository;

  GetInventoryEntriesUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required int start,
    required int end,
    String? searchQuery,
    String? warehouseFilter,
    DateTimeRange? dateRange,
  }) {
    return repository.getEntries(
      start: start,
      end: end,
      searchQuery: searchQuery,
      warehouseFilter: warehouseFilter,
      dateRange: dateRange,
    );
  }
}
