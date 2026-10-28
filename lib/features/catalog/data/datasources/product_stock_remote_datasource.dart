import 'package:supabase_flutter/supabase_flutter.dart';

class ProductStockRemoteDataSource {
  final SupabaseClient _supabase;

  ProductStockRemoteDataSource(this._supabase);

  Future<Map<String, int>> getProductStock({List<String>? productIds}) async {
    var query = _supabase
        .from('warehouse_stock_batches')
        .select('product_id, available_quantity');
    if (productIds != null && productIds.isNotEmpty) {
      query = query.inFilter('product_id', productIds);
    }
    final response = await query;
    final map = <String, int>{};
    for (final row in response) {
      final pId = row['product_id'] as String?;
      final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
      if (pId != null) {
        map[pId] = (map[pId] ?? 0) + qty;
      }
    }
    return map;
  }

  Future<Map<String, int>> getStockByVariant(String productId) async {
    final response = await _supabase
        .from('warehouse_stock_batches')
        .select('variant_id, available_quantity')
        .eq('product_id', productId);

    final map = <String, int>{};
    for (final row in response) {
      final vId = row['variant_id'] as String?;
      final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
      if (vId != null) {
        map[vId] = (map[vId] ?? 0) + qty;
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    final response = await _supabase
        .from('warehouse_stock_batches')
        .select('id, batch_number, expiry_date, available_quantity')
        .eq('variant_id', variantId)
        .eq('warehouse_id', warehouseId)
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }
}
