import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

abstract class KardexRepository {
  Future<List<KardexMovementEntity>> getKardexMovements({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
    int page = 0,
    int pageSize = 12,
  });

  Future<int> getKardexMovementsCount({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
  });

  Future<List<KardexMovementEntity>> getAllKardexMovements({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
  });
}
