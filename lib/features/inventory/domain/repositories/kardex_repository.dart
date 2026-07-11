import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/kardex_movement_model.dart';

abstract class KardexRepository {
  Future<List<KardexMovementModel>> getKardexMovements({
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

  Future<List<KardexMovementModel>> getAllKardexMovements({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
  });
}
