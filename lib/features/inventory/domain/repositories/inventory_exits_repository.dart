import 'package:flutter/material.dart';

abstract class InventoryExitsRepository {
  Future<Map<String, dynamic>> getExits({
    required int start,
    required int end,
    String? searchQuery,
    DateTimeRange? dateRange,
  });

  Future<List<dynamic>> getExitItems(String exitId);

  Future<List<dynamic>> getActiveWarehouses();

  Future<Map<String, dynamic>> getActiveProductsAndVariants();

  Future<List<dynamic>> getBatchesForVariant(
    String variantId,
    String warehouseId,
  );

  Future<void> saveExitTransaction({
    required String warehouseId,
    required String reason,
    required String? notes,
    required String? createdByProfileId,
    required List<dynamic> items,
  });
}
