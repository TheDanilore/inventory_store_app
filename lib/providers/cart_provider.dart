import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartProvider with ChangeNotifier {
  Map<String, CartItemModel> _items = {};
  bool _disposed = false;

  Map<String, CartItemModel> get items => {..._items};
  int get itemCount => _items.length;

  List<CartItemModel> get selectedItems =>
      _items.values.where((item) => item.isSelected).toList();

  int get selectedItemCount => selectedItems.length;

  double get selectedTotalAmount {
    var total = 0.0;
    for (final item in selectedItems) {
      total += item.totalItemPrice;
    }
    return total;
  }

  bool get isAllSelected =>
      _items.isNotEmpty && _items.values.every((item) => item.isSelected);

  CartProvider() {
    _initCart();
  }

  Future<void> _initCart() async {
    // 1. Carga local primero (UI no queda en blanco sin internet)
    await loadCartFromPrefs();

    // 2. Si ya hay sesión, sincronizamos con la nube
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await _downloadCloudCart();
    }

    // 3. Escuchamos cambios de sesión
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (_disposed) return;
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _downloadCloudCart();
      } else if (event == AuthChangeEvent.signedOut) {
        _items.clear();
        _saveCartToPrefs();
        if (!_disposed) notifyListeners();
      }
    });
  }

  // ── Obtener profileId de forma segura ────────────────────────────────────
  Future<String?> _getProfileId(
    SupabaseClient supabase,
    String authUserId,
  ) async {
    final profile =
        await supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', authUserId)
            .maybeSingle();
    return profile?['id'] as String?;
  }

  // ── Obtener o crear cartId de forma segura ────────────────────────────────
  Future<String?> _getOrCreateCartId(
    SupabaseClient supabase,
    String profileId,
  ) async {
    final existing =
        await supabase
            .from('shopping_carts')
            .select('id')
            .eq('profile_id', profileId)
            .maybeSingle();

    if (existing != null) {
      return existing['id'] as String?;
    }

    final created =
        await supabase
            .from('shopping_carts')
            .insert({'profile_id': profileId})
            .select('id')
            .maybeSingle();
    return created?['id'] as String?;
  }

  // ── Descargar carrito desde la nube ──────────────────────────────────────
  Future<void> _downloadCloudCart() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final supabase = Supabase.instance.client;

      final profileId = await _getProfileId(supabase, user.id);
      if (profileId == null) {
        debugPrint('CartProvider: perfil no encontrado para el usuario.');
        return;
      }

      final cartId = await _getOrCreateCartId(supabase, profileId);
      if (cartId == null) {
        debugPrint('CartProvider: no se pudo obtener o crear el carrito.');
        return;
      }

      final itemsResponse = await supabase
          .from('cart_items')
          .select('''
            quantity,
            variant_id,
            is_selected,
            products (
              id, name, description, unit_cost, sale_price,
              wholesale_price, wholesale_min_quantity, is_active,
              product_images (*)
            ),
            product_variants (
              id, product_id, sku, attributes, sale_price, wholesale_price,
              wholesale_min_quantity, is_active, reorder_point,
              product_images (*)
            )
          ''')
          .eq('cart_id', cartId);

      final Map<String, CartItemModel> cloudItems = {};

      for (final row in List<Map<String, dynamic>>.from(itemsResponse)) {
        // ── Proteger product join ──────────────────────────────────────────────
        final rawProduct = row['products'];
        // Supabase puede devolver Map o List según el join; normalizamos
        final productJson =
            rawProduct is Map
                ? rawProduct
                : (rawProduct is List && rawProduct.isNotEmpty
                    ? rawProduct.first
                    : null);
        if (productJson == null) continue;

        final product = ProductModel.fromJson(
          Map<String, dynamic>.from(productJson as Map),
        );

        final qty = (row['quantity'] as num?)?.toInt() ?? 1;
        final isSelected = row['is_selected'] as bool? ?? true;
        final rawVariantId = row['variant_id'] as String?;

        // ── Proteger variant join (puede ser null, Map, o List vacía) ──────────
        final rawVariant = row['product_variants'];
        final variantJson =
            rawVariant is Map
                ? rawVariant
                : (rawVariant is List && rawVariant.isNotEmpty
                    ? rawVariant.first
                    : null);

        ProductVariantModel? variant;
        if (variantJson != null) {
          try {
            variant = ProductVariantModel.fromJson(
              Map<String, dynamic>.from(variantJson as Map),
            );
          } catch (e) {
            debugPrint('CartProvider: error parseando variante: $e');
          }
        }

        final finalVariantId = variant?.id ?? rawVariantId;
        final cartKey = CartItemModel.buildKey(product.id, finalVariantId);

        cloudItems[cartKey] = CartItemModel(
          product: product,
          quantity: qty,
          variantId: finalVariantId,
          variantLabel:
              variant?.label ??
              (finalVariantId != null ? 'Variante seleccionada' : null),
          unitPrice: variant?.salePrice ?? product.salePrice,
          wholesalePrice: variant?.wholesalePrice ?? product.wholesalePrice,
          imageUrl: variant?.primaryImageUrl ?? product.primaryImageUrl,
          sku: variant?.sku,
          availableStock: 999,
          cartKey: cartKey,
          isSelected: isSelected,
        );
      }
      // Fusión: items locales que no están en la nube (agregados sin internet)
      bool localChanged = false;
      for (final localItem in _items.values) {
        if (!cloudItems.containsKey(localItem.cartKey)) {
          cloudItems[localItem.cartKey] = localItem;
          localChanged = true;
        }
      }

      _items = cloudItems;
      _saveCartToPrefs();
      if (!_disposed) notifyListeners();

      if (localChanged) _syncToCloud();
    } catch (e) {
      debugPrint('Error descargando carrito de la nube: $e');
    }
  }

  // ── Cargar carrito local ──────────────────────────────────────────────────
  Future<void> loadCartFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString('local_cart');
      if (cartString != null) {
        final Map<String, dynamic> decodedMap = json.decode(cartString);
        _items = decodedMap.map(
          (key, value) => MapEntry(key, CartItemModel.fromJson(value)),
        );
        if (!_disposed) notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al cargar el carrito local: $e');
    }
  }

  // ── Guardar local + sincronizar nube ──────────────────────────────────────
  Future<void> _saveCartToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedMap = json.encode(
        _items.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString('local_cart', encodedMap);
      _syncToCloud(); // fire-and-forget
    } catch (e) {
      debugPrint('Error al guardar el carrito: $e');
    }
  }

  // ── Sincronizar a Supabase ────────────────────────────────────────────────
  Future<void> _syncToCloud() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final supabase = Supabase.instance.client;

      final profileId = await _getProfileId(supabase, user.id);
      if (profileId == null) return;

      final cartId = await _getOrCreateCartId(supabase, profileId);
      if (cartId == null) return;

      await supabase.from('cart_items').delete().eq('cart_id', cartId);

      if (_items.isNotEmpty) {
        final itemsToInsert =
            _items.values.map((item) {
              final vid = item.variantId;
              return {
                'cart_id': cartId,
                'product_id': item.product.id,
                'variant_id': (vid == null || vid.isEmpty) ? null : vid,
                'quantity': item.quantity,
                'is_selected': item.isSelected,
              };
            }).toList();

        await supabase
            .from('cart_items')
            .upsert(
              itemsToInsert,
              onConflict: 'cart_id, product_id, variant_id',
            );
      }
    } catch (e) {
      debugPrint('Error sincronizando a la nube: $e');
    }
  }

  // ── Selección ─────────────────────────────────────────────────────────────
  void toggleItemSelection(String cartKey) {
    if (_items.containsKey(cartKey)) {
      _items[cartKey]!.isSelected = !_items[cartKey]!.isSelected;
      notifyListeners();
      _saveCartToPrefs();
    }
  }

  void toggleAllSelection(bool select) {
    for (var item in _items.values) {
      item.isSelected = select;
    }
    notifyListeners();
    _saveCartToPrefs();
  }

  void removeSelectedItems() {
    _items.removeWhere((key, item) => item.isSelected);
    notifyListeners();
    _saveCartToPrefs();
  }

  // ── CRUD del carrito ──────────────────────────────────────────────────────
  void addItem(
    ProductModel product, {
    int quantity = 1,
    String? variantId,
    String? variantLabel,
    double? unitPrice,
    double? wholesalePrice,
    String? imageUrl,
    String? sku,
    int? availableStock,
  }) {
    final safeVariantId =
        (variantId != null && variantId.trim().isEmpty) ? null : variantId;
    final key = CartItemModel.buildKey(product.id, safeVariantId);
    final maxStock = availableStock ?? product.totalStock.toInt();

    if (_items.containsKey(key)) {
      _items.update(key, (existing) {
        final newQty = existing.quantity + quantity;
        existing.quantity = newQty > maxStock ? maxStock : newQty;
        existing.isSelected = true;
        return existing;
      });
    } else {
      _items.putIfAbsent(
        key,
        () => CartItemModel(
          product: product,
          quantity: quantity.clamp(0, maxStock),
          variantId: safeVariantId,
          variantLabel: variantLabel,
          unitPrice: unitPrice ?? product.salePrice,
          wholesalePrice: wholesalePrice,
          imageUrl: imageUrl,
          sku: sku,
          availableStock: maxStock,
          cartKey: key,
          isSelected: true,
        ),
      );
    }
    notifyListeners();
    _saveCartToPrefs();
  }

  void removeItem(String cartKey) {
    _items.remove(cartKey);
    notifyListeners();
    _saveCartToPrefs();
  }

  void removeSingleItem(String cartKey) {
    if (!_items.containsKey(cartKey)) return;
    if (_items[cartKey]!.quantity > 1) {
      _items.update(cartKey, (existing) {
        existing.quantity -= 1;
        return existing;
      });
    } else {
      _items.remove(cartKey);
    }
    notifyListeners();
    _saveCartToPrefs();
  }

  void setQuantity(String cartKey, int quantity) {
    if (!_items.containsKey(cartKey)) return;
    if (quantity <= 0) {
      _items.remove(cartKey);
    } else {
      _items.update(cartKey, (existing) {
        existing.quantity =
            quantity > existing.availableStock
                ? existing.availableStock
                : quantity;
        return existing;
      });
    }
    notifyListeners();
    _saveCartToPrefs();
  }

  void updateItemStock(String cartKey, int realStock) {
    if (!_items.containsKey(cartKey)) return;
    _items.update(cartKey, (existing) {
      existing.availableStock = realStock;
      if (existing.quantity > realStock) {
        existing.quantity = realStock > 0 ? realStock : 1;
      }
      return existing;
    });
    notifyListeners();
    _saveCartToPrefs();
  }

  void clear() {
    _items = {};
    notifyListeners();
    _saveCartToPrefs();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
