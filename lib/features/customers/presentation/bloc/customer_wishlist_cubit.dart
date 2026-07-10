import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_wishlist_state.dart';

@injectable
class CustomerWishlistCubit extends Cubit<CustomerWishlistState> {
  final SupabaseClient _supabase;
  static const int _limit = 15;

  CustomerWishlistCubit()
      : _supabase = Supabase.instance.client,
        super(CustomerWishlistInitial());

  Future<void> fetchWishlist({required String profileId, bool reset = false}) async {
    final currentState = state;
    List<WishlistEntryModel> currentItems = [];

    if (currentState is CustomerWishlistLoaded) {
      currentItems = currentState.items;
    }

    if (reset) {
      currentItems = [];
      emit(CustomerWishlistLoading());
    } else {
      if (currentState is CustomerWishlistLoaded && currentState.hasReachedMax) {
        return;
      }
    }

    final offset = currentItems.length;

    try {
      final response = await _supabase
          .from('wishlist')
          .select('''
            id, profile_id, product_id, created_at, 
            products(id, name, unit_cost, sale_price, description, wholesale_price, wholesale_min_quantity, is_active, product_images(*))
          ''')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .range(offset, offset + _limit - 1);

      final rows = List<Map<String, dynamic>>.from(response);

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

      final fetchedEntries = rows.map((row) {
        final productJson = Map<String, dynamic>.from(row['products'] as Map);
        final pid = productJson['id'] as String?;
        final stock = pid == null ? 0 : (stockByProduct[pid] ?? 0);

        return WishlistEntryModel(
          wishlistId: row['id'] as String,
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          product: ProductModel.fromJson(productJson).copyWith(totalStock: stock),
        );
      }).toList();

      emit(CustomerWishlistLoaded(
        items: reset ? fetchedEntries : [...currentItems, ...fetchedEntries],
        hasReachedMax: fetchedEntries.length < _limit,
      ));
    } catch (e) {
      emit(CustomerWishlistError('No se pudo cargar la lista de deseos: $e'));
    }
  }

  Future<void> removeFromWishlist(String profileId, WishlistEntryModel entry) async {
    final currentState = state;
    if (currentState is CustomerWishlistLoaded) {
      try {
        await _supabase
            .from('wishlist')
            .delete()
            .eq('profile_id', profileId)
            .eq('product_id', entry.product.id);

        final updatedItems = currentState.items
            .where((i) => i.wishlistId != entry.wishlistId)
            .toList();

        emit(currentState.copyWith(items: updatedItems));
      } catch (e) {
        // Emit error, then re-emit loaded state to clear error
        emit(CustomerWishlistError(e.toString()));
        emit(currentState);
      }
    }
  }
}
