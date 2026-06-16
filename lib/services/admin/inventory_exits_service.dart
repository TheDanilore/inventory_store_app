import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryExitsService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getExits({
    required int start,
    required int end,
    String? searchQuery,
    DateTimeRange? dateRange,
  }) async {
    var query = _supabase
        .from('inventory_exits')
        .select('''
          id, created_at, reason, notes,
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
          .lte('created_at', dateRange.end.add(const Duration(days: 1)).toIso8601String());
    }

    final resp = await query.order('created_at', ascending: false).range(start, end).count(CountOption.exact);

    return {
      'data': resp.data as List<dynamic>,
      'count': resp.count,
    };
  }

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
}
