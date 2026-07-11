import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';

@injectable
class GetInventoryExitsUseCase {
  final InventoryExitsRepository repository;

  GetInventoryExitsUseCase(this.repository);

  Future<Map<String, dynamic>> call({
    required int start,
    required int end,
    String? searchQuery,
    DateTimeRange? dateRange,
  }) async {
    return repository.getExits(
      start: start,
      end: end,
      searchQuery: searchQuery,
      dateRange: dateRange,
    );
  }
}
