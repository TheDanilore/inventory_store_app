import 'dart:developer' as developer;
import 'dart:io' show SocketException;
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
    try {
      final response = await _supabase
          .from('wishlist')
          .select('''
            id, profile_id, product_id, created_at,
            products(
              id, name, is_active, uses_batches, stock_control,
              product_images(id, product_id, image_url, is_main, display_order),
              product_variants(id, product_id, sale_price, unit_cost, is_active, sku)
            )
          ''')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final rows = List<Map<String, dynamic>>.from(response);

      // Enriquecer con stock
      final productIds =
          rows
              .map((r) {
                final p = r['products'];
                if (p is Map) return p['id'] as String?;
                if (p is List && p.isNotEmpty && p.first is Map) {
                  return (p.first as Map)['id'] as String?;
                }
                return null;
              })
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
          stockByProduct[pid] =
              (stockByProduct[pid] ?? 0) +
              ((row['available_quantity'] as num?)?.toInt() ?? 0);
        }
      }

      final result = <WishlistEntryEntity>[];
      for (final row in rows) {
        final rawProducts = row['products'];
        if (rawProducts == null) continue;

        try {
          final productMap =
              rawProducts is Map
                  ? Map<String, dynamic>.from(rawProducts)
                  : (rawProducts is List && rawProducts.isNotEmpty
                      ? Map<String, dynamic>.from(rawProducts.first as Map)
                      : <String, dynamic>{});
          if (productMap.isEmpty) continue;

          final pid = productMap['id'] as String?;
          final stock = pid == null ? 0 : (stockByProduct[pid] ?? 0);

          result.add(
            WishlistEntryEntity(
              wishlistId: row['id'] as String,
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
              product:
                  ProductModel.fromJson(
                    productMap,
                  ).copyWith(totalStock: stock).toEntity(),
            ),
          );
        } catch (e, st) {
          developer.log(
            'Error crítico al parsear ítem de wishlist (ID: ${row['id']})',
            error: e,
            stackTrace: st,
            name: 'WishlistRepositoryImpl',
          );
          continue;
        }
      }
      return result;
    } on PostgrestException catch (e, st) {
      developer.log(
        'Error de Supabase al consultar la lista de deseos',
        error: e.message,
        stackTrace: st,
        name: 'WishlistRepositoryImpl',
      );
      rethrow;
    } on SocketException catch (e, st) {
      developer.log(
        'Error de red al consultar la lista de deseos',
        error: e,
        stackTrace: st,
        name: 'WishlistRepositoryImpl',
      );
      rethrow;
    } catch (e, st) {
      developer.log(
        'Error inesperado al consultar la lista de deseos',
        error: e,
        stackTrace: st,
        name: 'WishlistRepositoryImpl',
      );
      rethrow;
    }
  }

  @override
  Future<void> removeFromWishlist({
    required String profileId,
    required String productId,
  }) async {
    try {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('profile_id', profileId)
          .eq('product_id', productId);
    } on PostgrestException catch (e, st) {
      developer.log(
        'Error de Supabase al eliminar ítem de lista de deseos',
        error: e.message,
        stackTrace: st,
        name: 'WishlistRepositoryImpl',
      );
      rethrow;
    } on SocketException catch (e, st) {
      developer.log(
        'Error de red al eliminar ítem de lista de deseos',
        error: e,
        stackTrace: st,
        name: 'WishlistRepositoryImpl',
      );
      rethrow;
    } catch (e, st) {
      developer.log(
        'Error inesperado al eliminar ítem de lista de deseos',
        error: e,
        stackTrace: st,
        name: 'WishlistRepositoryImpl',
      );
      rethrow;
    }
  }
}
