import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';

class ProductDetailService {
  final _supabase = Supabase.instance.client;

  Future<({
    List<Map<String, dynamic>> stocks,
    List<Map<String, dynamic>> batches,
    List<ProductImageModel> images,
    List<ProductVariantModel> variants,
    List<Map<String, dynamic>> reviews,
    List<Map<String, dynamic>> ingredients,
  })> fetchProductExtraData(String productId) async {
    final queries = <Future<dynamic>>[
      // 0: Stocks / Batches — solo stock > 0 (filtro servidor)
      _supabase
          .from('warehouse_stock_batches')
          .select(
            'id, available_quantity, variant_id, warehouse_id, batch_number, expiry_date, warehouses(name)',
          )
          .eq('product_id', productId)
          .gt('available_quantity', 0)
          .order('expiry_date', ascending: true, nullsFirst: false),

      // 1: Images — columnas minimas
      _supabase
          .from('product_images')
          .select('id, product_id, variant_id, image_url, display_order, is_main')
          .eq('product_id', productId)
          .order('display_order', ascending: true),

      // 2: Variants — columnas minimas en product_images (sin *)
      _supabase
          .from('product_variants')
          .select(
            'id, product_id, sku, '
            'variant_attribute_values(attribute_values(id, value, attributes(name))), '
            'product_images(id, image_url, variant_id), '
            'sale_price, wholesale_price, wholesale_min_quantity, '
            'reorder_point, is_active, unit_cost',
          )
          .eq('product_id', productId)
          .eq('is_active', true)
          .order('created_at', ascending: true),

      // 3: Reviews — ultimas 50 (paginacion ligera)
      _supabase
          .from('product_reviews')
          .select('rating, comment, user_name, created_at')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(50),

      // 4: Ingredients
      _supabase
          .from('product_active_ingredients')
          .select('concentration, unit, active_ingredients(id, name, description)')
          .eq('product_id', productId),
    ];

    final results = await Future.wait(queries);

    final rawStocks = results[0] as List<dynamic>;
    final aggregatedStocks = <String, Map<String, dynamic>>{};
    final validBatches = <Map<String, dynamic>>[];

    for (final row in rawStocks) {
      final wId = row['warehouse_id']?.toString() ?? 'unknown';
      final vId = row['variant_id']?.toString() ?? 'none';
      final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;

      if (stock > 0) {
        validBatches.add(Map<String, dynamic>.from(row as Map));
        final key = '${wId}_$vId';
        if (aggregatedStocks.containsKey(key)) {
          aggregatedStocks[key]!['available_quantity'] =
              (aggregatedStocks[key]!['available_quantity'] as int) + stock;
        } else {
          aggregatedStocks[key] = {
            'warehouse_id': row['warehouse_id'],
            'variant_id': row['variant_id'],
            'warehouses': row['warehouses'],
            'available_quantity': stock,
          };
        }
      }
    }

    return (
      stocks: aggregatedStocks.values.toList(),
      batches: validBatches,
      images: (results[1] as List)
          .map((e) => ProductImageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      variants: (results[2] as List)
          .map((e) => ProductVariantModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      reviews: List<Map<String, dynamic>>.from(results[3] as List),
      ingredients: List<Map<String, dynamic>>.from(results[4] as List),
    );
  }

  Future<List<Map<String, dynamic>>> fetchAdminFinancialData(String productId) async {
    // Limitado a 500 registros para evitar egress masivo en productos con muchas ventas.
    final response = await _supabase
        .from('order_items')
        .select('quantity, unit_cost, applied_price, variant_id, orders!inner(status)')
        .eq('product_id', productId)
        .eq('orders.status', 'COMPLETED')
        .limit(500);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Obtiene el profile_id del usuario autenticado. Retorna null si no esta logueado.
  /// Se llama una sola vez al inicializar el provider para cachear el resultado.
  Future<String?> fetchCurrentProfileId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final profile = await _supabase
        .from('profiles')
        .select('id')
        .eq('auth_user_id', user.id)
        .maybeSingle();
    return profile?['id'] as String?;
  }

  Future<bool> checkWishlistState(String productId, String profileId) async {
    final wish = await _supabase
        .from('wishlist')
        .select('id')
        .eq('profile_id', profileId)
        .eq('product_id', productId)
        .maybeSingle();
    return wish != null;
  }

  Future<bool> toggleWishlist(
    String productId,
    String profileId,
    bool currentState,
  ) async {
    if (currentState) {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('profile_id', profileId)
          .eq('product_id', productId);
      return false;
    } else {
      await _supabase.from('wishlist').insert({
        'profile_id': profileId,
        'product_id': productId,
      });
      return true;
    }
  }
}
