import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await _supabase
        .from('categories')
        .select('id, name')
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> fetchProducts({
    required int offset,
    required int limit,
    String? categoryId,
    String searchTerm = '',
  }) async {
    var query = _supabase
        .from('products')
        .select('''
          *,
          product_images!inner(*),
          product_variants(
            *,
            product_images(id, image_url, is_main, display_order),
            variant_attribute_values(
              attribute_values(id, value, attributes(id, name))
            )
          ),
          warehouse_stock_batches(*)
        ''')
        .eq('is_active', true);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (searchTerm.isNotEmpty) {
      query = query.ilike('name', '%$searchTerm%');
    }

    final response = await query
        .order('name')
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> loadStockByProductIds(List<String> ids) async {
    if (ids.isEmpty) return {};

    final response = await _supabase
        .from('product_stock_summary')
        .select('product_id, total_stock')
        .inFilter('product_id', ids);

    final map = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(response)) {
      final pid = row['product_id'] as String?;
      final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
      if (pid != null) {
        map[pid] = stock;
      }
    }
    return map;
  }

  Future<Map<String, int>> loadStockByVariant(String productId) async {
    final response = await _supabase
        .from('product_stock_summary')
        .select('variant_id, total_stock')
        .eq('product_id', productId);

    final map = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(response)) {
      final vid = row['variant_id'] as String?;
      final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
      if (vid != null) {
        map[vid] = stock;
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> loadActiveVariants(
    String productId,
  ) async {
    final response = await _supabase
        .from('product_variants')
        .select('''
          *,
          product_images(id, image_url, is_main, display_order),
          variant_attribute_values(
            attribute_values(id, value, attributes(id, name))
          )
        ''')
        .eq('product_id', productId)
        .eq('is_active', true)
        .order('sku');

    return List<Map<String, dynamic>>.from(response);
  }
}
