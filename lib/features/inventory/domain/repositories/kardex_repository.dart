import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/data/models/kardex_movement_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

abstract class KardexRepository {
  /// Returns entities — used by domain use cases (PDF export, etc.)
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

  /// Returns rich display models — used by the presentation layer (KardexCard, etc.)
  Future<List<KardexMovementModel>> getKardexMovementsForDisplay({
    DateTimeRange? dateRange,
    String typeFilter = 'ALL',
    String searchText = '',
    int page = 0,
    int pageSize = 12,
  });
}
