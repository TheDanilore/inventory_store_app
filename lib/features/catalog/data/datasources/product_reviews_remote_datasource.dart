import 'package:supabase_flutter/supabase_flutter.dart';

class ProductReviewsRemoteDataSource {
  final SupabaseClient _supabase;

  ProductReviewsRemoteDataSource(this._supabase);

  Future<bool> checkCustomerPurchase(String productId, String profileId) async {
    final purchases = await _supabase
        .from('customer_orders')
        .select('id, customer_order_items!inner(product_id)')
        .eq('profile_id', profileId)
        .eq('customer_order_items.product_id', productId)
        .eq('status', 'DELIVERED')
        .limit(1);

    return purchases.isNotEmpty;
  }

  Future<void> addProductReview({
    required String productId,
    required String profileId,
    required String userName,
    required int rating,
    String? comment,
  }) async {
    await _supabase.from('product_reviews').insert({
      'product_id': productId,
      'profile_id': profileId,
      'user_name': userName,
      'rating': rating,
      'comment': comment,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
