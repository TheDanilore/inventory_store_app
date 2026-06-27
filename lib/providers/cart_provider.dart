import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/services/customer/cart_cloud_service.dart';
import 'package:inventory_store_app/services/customer/cart_local_service.dart';

class CartProvider with ChangeNotifier {
  Map<String, CartItemModel> _items = {};
  bool _disposed = false;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  final CartCloudService _cloudService = CartCloudService();
  final CartLocalService _localService = CartLocalService();

  StreamSubscription? _authSubscription;
  Timer? _debounceTimer;

  Map<String, CartItemModel> get items => {..._items};
  int get itemCount => _items.length;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;

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
    _setLoading(true);

    // 1. Carga local primero
    _items = await _localService.loadCart();
    _setLoading(false);

    // 2. Si ya hay sesión, sincronizamos con la nube
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await _downloadCloudCart(user.id);
    }

    // 3. Escuchamos cambios de sesión
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (_disposed) return;
      final event = data.event;
      final sessionUser = data.session?.user;

      if (event == AuthChangeEvent.signedIn && sessionUser != null) {
        _downloadCloudCart(sessionUser.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _items.clear();
        _localService.clearCart();
        if (!_disposed) notifyListeners();
      }
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    if (!_disposed) notifyListeners();
  }

  void _setSyncing(bool value) {
    _isSyncing = value;
    if (!_disposed) notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    if (!_disposed) notifyListeners();
  }

  // ── Descargar carrito desde la nube ──────────────────────────────────────
  Future<void> _downloadCloudCart(String authUserId) async {
    _setSyncing(true);
    _setError(null);
    try {
      final cloudItems = await _cloudService.downloadCloudCart(authUserId);
      if (cloudItems == null) return;

      // Fusión: items locales que no están en la nube (agregados sin internet)
      bool localChanged = false;
      for (final localItem in _items.values) {
        if (!cloudItems.containsKey(localItem.cartKey)) {
          cloudItems[localItem.cartKey] = localItem;
          localChanged = true;
        }
      }

      _items = cloudItems;
      await _localService.saveCart(_items);

      if (localChanged) {
        _debouncedSyncToCloud();
      }
    } catch (e) {
      debugPrint('Error loading cart: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _setError('Sin conexión a internet.');
      } else {
        _setError('No se pudo cargar el carrito.');
      }
    } finally {
      _setSyncing(false);
    }
  }

  // ── Sincronizar a Supabase con Debounce ──────────────────────────────────
  void _debouncedSyncToCloud() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _syncToCloud();
    });
  }

  Future<void> _syncToCloud() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _setSyncing(true);
    _setError(null);
    try {
      await _cloudService.syncToCloud(user.id, _items);
    } catch (e) {
      debugPrint('Error applying coupon: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _setError('Sin conexión a internet.');
      } else {
        _setError('Error al aplicar el cupón.');
      }
    } finally {
      _setSyncing(false);
    }
  }

  // ── Selección ─────────────────────────────────────────────────────────────
  void toggleItemSelection(String cartKey) {
    if (_items.containsKey(cartKey)) {
      _items[cartKey]!.isSelected = !_items[cartKey]!.isSelected;
      _saveAndSync();
    }
  }

  void toggleAllSelection(bool select) {
    for (var item in _items.values) {
      item.isSelected = select;
    }
    _saveAndSync();
  }

  void removeSelectedItems() {
    _items.removeWhere((key, item) => item.isSelected);
    _saveAndSync();
  }

  // ── CRUD del carrito ──────────────────────────────────────────────────────
  void addItem(
    ProductModel product, {
    int quantity = 1,
    String? variantId,
    String? variantLabel,
    double? unitPrice,
    double? wholesalePrice,
    double? unitCost,
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
          unitCost:
              unitCost != null && unitCost > 0 ? unitCost : product.unitCost,
          wholesalePrice: wholesalePrice,
          imageUrl: imageUrl,
          sku: sku,
          availableStock: maxStock,
          cartKey: key,
          isSelected: true,
        ),
      );
    }
    _saveAndSync();
  }

  void removeItem(String cartKey) {
    if (_items.containsKey(cartKey)) {
      _items.remove(cartKey);
      _saveAndSync();
    }
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
    _saveAndSync();
  }

  void updateAvailableStock(String cartKey, int newStock) {
    if (_items.containsKey(cartKey)) {
      _items.update(cartKey, (existing) {
        existing.availableStock = newStock;
        if (newStock <= 0) {
          existing.isSelected = false;
        } else if (existing.quantity > newStock) {
          existing.quantity = newStock;
        }
        return existing;
      });
      _saveAndSync();
    }
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
    _saveAndSync();
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
    _saveAndSync();
  }

  void clear() {
    _items = {};
    _saveAndSync();
  }

  void _saveAndSync() {
    if (!_disposed) notifyListeners();
    _localService.saveCart(_items);
    _debouncedSyncToCloud();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
