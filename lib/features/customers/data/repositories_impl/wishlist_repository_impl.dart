import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/customers/domain/entities/wishlist_entry_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/wishlist_repository.dart';

@LazySingleton(as: WishlistRepository)
class WishlistRepositoryImpl implements WishlistRepository {
  final SupabaseClient _supabase;

  WishlistRepositoryImpl(this._supabase);

  @override
  Future<List<WishlistEntryEntity>> getWishlist({
    required String profileId,
    required int limit,
    required int offset,
  }) async {
    final response = await _supabase
        .from('wishlist')
        .select('''
          id, profile_id, product_id, created_at,
          products(id, name, unit_cost, sale_price, description,
                   wholesale_price, wholesale_min_quantity, is_active,
                   product_images(*))
        ''')
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final rows = List<Map<String, dynamic>>.from(response);

    // Enriquecer con stock
    final productIds = rows
        .map((r) => (r['products'] as Map<String, dynamic>?)?['id'] as String?)
        .whereType<String>()
        .toList();

    Map<String, int> stockByProduct = {};
    if (productIds.isNotEmpty) {
      final stockResponse = await _supabase
          .from('warehouse_stock_batches')
          .select('product_id, available_quantity')
          .inFilter('product_id', productIds)
          .gt('available_quantity', 0);

      for (final row in List<Map<String, dynamic>>.from(stockResponse)) {
        final pid = row['product_id'] as String;
        stockByProduct[pid] = (stockByProduct[pid] ?? 0) +
            ((row['available_quantity'] as num?)?.toInt() ?? 0);
      }
    }

    return rows.map((row) {
      final productJson = Map<String, dynamic>.from(row['products'] as Map);
      final pid = productJson['id'] as String?;
      final stock = pid == null ? 0 : (stockByProduct[pid] ?? 0);

      return WishlistEntryEntity(
        wishlistId: row['id'] as String,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        product: ProductModel.fromJson(productJson)
            .copyWith(totalStock: stock)
            .toEntity(),
      );
    }).toList();
  }

  @override
  Future<void> removeFromWishlist({
    required String profileId,
    required String productId,
  }) async {
    await _supabase
        .from('wishlist')
        .delete()
        .eq('profile_id', profileId)
        .eq('product_id', productId);
  }
}
