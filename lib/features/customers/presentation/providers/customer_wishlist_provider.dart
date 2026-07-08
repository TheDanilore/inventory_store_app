import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';

class WishlistEntryModel {
  final String wishlistId;
  final DateTime? createdAt;
  final ProductModel product;

  WishlistEntryModel({
    required this.wishlistId,
    required this.createdAt,
    required this.product,
  });
}

class CustomerWishlistProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<WishlistEntryModel> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _profileId;
  String _errorMessage = '';

  final Map<String, bool> _processingItems = {};
  static const int _limit = 15;

  List<WishlistEntryModel> get items => _items;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get profileId => _profileId;
  String get errorMessage => _errorMessage;

  bool isItemProcessing(String wishlistId) =>
      _processingItems[wishlistId] == true;

  Future<void> init() async {
    await fetchWishlist(reset: true);
  }

  Future<void> fetchWishlist({bool reset = false}) async {
    if (reset) {
      if (_items.isEmpty) _isLoading = true;
      _errorMessage = '';
      _hasMore = true;
      notifyListeners();

      // Intentamos cargar el profileId si no existe
      if (_profileId == null) {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          _isLoading = false;
          notifyListeners();
          return;
        }
        try {
          final profile =
              await _supabase
                  .from('profiles')
                  .select('id')
                  .eq('auth_user_id', user.id)
                  .maybeSingle();
          _profileId = profile?['id'] as String?;
        } catch (e) {
          _errorMessage = 'Error al obtener perfil: $e';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    if (_profileId == null) {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
      return;
    }

    final offset = reset ? 0 : _items.length;

    try {
      // Optimizamos el select usando columnas específicas
      final response = await _supabase
          .from('wishlist')
          .select('''
            id, profile_id, product_id, created_at, 
            products(id, name, unit_cost, sale_price, description, wholesale_price, wholesale_min_quantity, is_active, product_images(*))
          ''')
          .eq('profile_id', _profileId!)
          .order('created_at', ascending: false)
          .range(offset, offset + _limit - 1);

      final rows = List<Map<String, dynamic>>.from(response);

      // Cargar stock en paralelo solo para los productos obtenidos en esta página
      final productIds =
          rows
              .map(
                (r) =>
                    (r['products'] as Map<String, dynamic>?)?['id'] as String?,
              )
              .whereType<String>()
              .toList();

      Map<String, int> stockByProduct = {};
      if (productIds.isNotEmpty) {
        final stockResponse = await _supabase
            .from('warehouse_stock_batches')
            .select('product_id, available_quantity')
            .inFilter('product_id', productIds)
            .gt('available_quantity', 0); // Filtro en el backend

        for (final row in List<Map<String, dynamic>>.from(stockResponse)) {
          final pid = row['product_id'] as String;
          stockByProduct[pid] =
              (stockByProduct[pid] ?? 0) +
              ((row['available_quantity'] as num?)?.toInt() ?? 0);
        }
      }

      final fetchedEntries =
          rows.map((row) {
            final productJson = Map<String, dynamic>.from(
              row['products'] as Map,
            );
            final pid = productJson['id'] as String?;
            final stock = pid == null ? 0 : (stockByProduct[pid] ?? 0);

            return WishlistEntryModel(
              wishlistId: row['id'] as String,
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
              product: ProductModel.fromJson(
                productJson,
              ).copyWith(totalStock: stock),
            );
          }).toList();

      if (reset) {
        _items = fetchedEntries;
      } else {
        _items.addAll(fetchedEntries);
      }

      _hasMore = fetchedEntries.length == _limit;
      _errorMessage = '';
    } catch (e) {
      debugPrint('Error al cargar wishlist: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'No se pudo cargar la lista de deseos.';
      }
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> removeFromWishlist(WishlistEntryModel entry) async {
    if (_profileId == null) return;

    _setItemProcessing(entry.wishlistId, true);

    try {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('profile_id', _profileId!)
          .eq('product_id', entry.product.id);

      _items.removeWhere((i) => i.wishlistId == entry.wishlistId);
      // No seteamos error, la UI puede mostrar un SnackBar local de éxito si lo requiere.
    } catch (e) {
      throw Exception('No se pudo eliminar de la lista de deseos: $e');
    } finally {
      _setItemProcessing(entry.wishlistId, false);
    }
  }

  void _setItemProcessing(String wishlistId, bool isProcessing) {
    if (isProcessing) {
      _processingItems[wishlistId] = true;
    } else {
      _processingItems.remove(wishlistId);
    }
    notifyListeners();
  }
}
