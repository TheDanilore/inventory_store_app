import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/kardex_repository.dart';

@injectable
class GetKardexMovementsUseCase {
  final KardexRepository repository;

  GetKardexMovementsUseCase(this.repository);

  Future<List<KardexMovementEntity>> call({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
    int page = 0,
    int pageSize = 12,
  }) {
    return repository.getKardexMovements(
      dateRange: dateRange,
      typeFilter: typeFilter,
      searchText: searchText,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<int> count({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
  }) {
    return repository.getKardexMovementsCount(
      dateRange: dateRange,
      typeFilter: typeFilter,
      searchText: searchText,
    );
  }
}
