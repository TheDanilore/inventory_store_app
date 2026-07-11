import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_model.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';

@LazySingleton(as: InventoryExitsRepository)
class InventoryExitsRepositoryImpl implements InventoryExitsRepository {
  final _supabase = Supabase.instance.client;

  @override
  Future<({List<InventoryExitEntity> data, int count})> getExits({
    required int start,
    required int end,
    String? searchQuery,
    DateTimeRange? dateRange,
  }) async {
    var query = _supabase.from('inventory_exits').select('''
          id, created_at, reason, notes, warehouse_id,
          warehouses(name),
          inventory_exit_items(quantity, unit_cost)
        ''');

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final sq = '%$searchQuery%';
      query = query.or('reason.ilike.$sq,notes.ilike.$sq');
    }

    if (dateRange != null) {
      query = query
          .gte('created_at', dateRange.start.toIso8601String())
          .lte(
            'created_at',
            dateRange.end.add(const Duration(days: 1)).toIso8601String(),
          );
    }

    final resp = await query
        .order('created_at', ascending: false)
        .range(start, end)
        .count(CountOption.exact);

    final data = (resp.data as List<dynamic>).map((e) => InventoryExitModel.fromJson(e).toEntity()).toList();
    return (data: data, count: resp.count);
  }

  @override
  Future<List<dynamic>> getExitItems(String exitId) async {
    final resp = await _supabase
        .from('inventory_exit_items')
        .select('''
          quantity, unit_cost, batch_number, variant_id,
          products!inner(
            name, 
            uses_batches,
            product_images(image_url, is_main, variant_id)
          ),
          product_variants!inner(
            sku,
            variant_attribute_values(
              attribute_values(value)
            )
          )
        ''')
        .eq('exit_id', exitId);

    return resp as List<dynamic>;
  }

  Future<List<dynamic>> getActiveWarehouses() async {
    return await _supabase
        .from('warehouses')
        .select('id, name')
        .eq('is_active', true);
  }

  Future<Map<String, dynamic>> getActiveProductsAndVariants() async {
    final results = await Future.wait([
      _supabase
          .from('products')
          .select('*, product_images(*)')
          .eq('is_active', true)
          .eq('stock_control', true)
          .neq('product_type', 'service')
          .order('name'),
      _supabase
          .from('product_variants')
          .select('''
            id, product_id, sku, sale_price, unit_cost, is_active,
            product_images(*),
            variant_attribute_values(
              attribute_values(id, value, attributes(id, name))
            )
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: true),
    ]);

    return {
      'products': results[0] as List<dynamic>,
      'variants': results[1] as List<dynamic>,
    };
  }

  @override
  Future<List<dynamic>> getBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    return await _supabase
        .from('warehouse_stock_batches')
        .select()
        .eq('variant_id', variantId)
        .eq('warehouse_id', warehouseId)
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);
  }

  @override
  Future<void> saveExitTransaction({
    required String warehouseId,
    required String reason,
    required String? notes,
    required String? createdByProfileId,
    required List<dynamic> items,
  }) async {
    // 1. Cabecera
    final exitHeader =
        await _supabase
            .from('inventory_exits')
            .insert({
              'warehouse_id': warehouseId,
              'reason': reason,
              'notes': notes,
              'created_by': createdByProfileId,
            })
            .select('id')
            .single();

    final exitId = exitHeader['id'] as String;

    for (final item in items) {
      final String batchId = item['batch_id'];
      final double quantity = item['quantity'];
      final String batchNumber = item['batch_number'];
      final String variantId = item['variant_id'];
      final String productId = item['product_id'];
      final double unitCost = item['unit_cost'];
      final double totalCost = item['total_cost'];
      final String productName = item['product_name'];

      // RE-VALIDACIÓN
      final currentBatch =
          await _supabase
              .from('warehouse_stock_batches')
              .select('available_quantity')
              .eq('id', batchId)
              .single();

      final double previousStock =
          (currentBatch['available_quantity'] as num).toDouble();
      final double newStock = previousStock - quantity;

      if (newStock < 0) {
        throw Exception(
          'Stock insuficiente para $productName (Lote: $batchNumber). Disponible actual: $previousStock',
        );
      }

      // Detalle de salida
      await _supabase.from('inventory_exit_items').insert({
        'exit_id': exitId,
        'product_id': productId,
        'variant_id': variantId,
        'quantity': quantity,
        'batch_number': batchNumber,
        'unit_cost': unitCost,
      });

      // Actualización Kardex Físico
      await _supabase
          .from('warehouse_stock_batches')
          .update({
            'available_quantity': newStock,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': createdByProfileId,
          })
          .eq('id', batchId);

      // Movimiento Kardex Valorizado
      await _supabase.from('inventory_movements').insert({
        'variant_id': variantId,
        'warehouse_id': warehouseId,
        'stock_batch_id': batchId,
        'inventory_exit_id': exitId,
        'quantity': -quantity,
        'previous_stock': previousStock,
        'new_stock': newStock,
        'unit_cost': unitCost,
        'total_cost': totalCost,
        'reason': 'EXIT',
        'notes': 'Salida por: $reason',
        'created_by': createdByProfileId,
      });
    }
  }
}
