import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';

class PosProvider with ChangeNotifier {
  final Map<String, CartItemModel> _items = {};

  // --- VARIABLES DE CONFIGURACIÓN DE VENTA ---
  String? _selectedClientId;
  String? _selectedClientName;
  int _saldoActualCliente = 0;
  int _puntosAUsar = 0;
  String _paymentMethod = 'EFECTIVO';
  String? _selectedWarehouseId;

  // Getters
  Map<String, CartItemModel> get items => {..._items};
  int get itemCount => _items.length;

  String? get selectedClientId => _selectedClientId;
  String? get selectedClientName => _selectedClientName;
  int get saldoActualCliente => _saldoActualCliente;
  int get puntosAUsar => _puntosAUsar;
  String get paymentMethod => _paymentMethod;
  String? get selectedWarehouseId => _selectedWarehouseId;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, item) => total += item.totalItemPrice);
    return total;
  }

  // --- SETTERS DE CONFIGURACIÓN ---
  void setClient(String? id, String? name, int saldo) {
    _selectedClientId = id;
    _selectedClientName = name;
    _saldoActualCliente = saldo;
    _puntosAUsar = 0; // Se resetean los puntos al cambiar de cliente
    notifyListeners();
  }

  void setPuntosAUsar(int puntos) {
    _puntosAUsar = puntos;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setWarehouse(String? id) {
    _selectedWarehouseId = id;
    notifyListeners();
  }

  // --- MÉTODOS DEL CARRITO ---
  void addProductToPos({
    required ProductModel product,
    required int quantity,
    String? variantId,
    String? variantLabel,
    double? unitPrice,
    double? wholesalePrice,
    String? imageUrl,
    String? sku,
    int? availableStock,
  }) {
    final key = CartItemModel.buildKey(product.id, variantId);

    if (_items.containsKey(key)) {
      _items.update(key, (existing) {
        existing.quantity += quantity;
        return existing;
      });
    } else {
      _items.putIfAbsent(
        key,
        () => CartItemModel(
          product: product,
          quantity: quantity,
          variantId: variantId,
          variantLabel: variantLabel,
          unitPrice: unitPrice ?? product.salePrice,
          wholesalePrice: wholesalePrice ?? product.wholesalePrice,
          imageUrl: imageUrl,
          sku: sku,
          availableStock: availableStock ?? product.totalStock,
          cartKey: key,
        ),
      );
    }
    notifyListeners();
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
  }

  void removeProduct(String key) {
    _items.remove(key);
    notifyListeners();
  }

  void clearPos() {
    _items.clear();
    // Limpiamos también la configuración al terminar la venta
    _selectedClientId = null;
    _selectedClientName = null;
    _saldoActualCliente = 0;
    _puntosAUsar = 0;
    _paymentMethod = 'EFECTIVO';
    // Nota: Dejamos el almacén (_selectedWarehouseId) como estaba por comodidad para la siguiente venta.
    notifyListeners();
  }
}
