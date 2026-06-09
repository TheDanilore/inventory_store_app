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

  // --- LOTES: override manual por cartKey ---
  // Guardamos los overrides aquí para que el checkout los lea y también los
  // pueda limpiar cuando cambia el almacén o se elimina un producto.
  // Clave: cartKey  →  lista de segmentos de lote asignados manualmente.
  // El tipo es `dynamic` para no crear dependencia circular con _BatchAssignment
  // del checkout. El checkout gestiona el tipo concreto; el provider solo lo almacena.
  final Map<String, List<dynamic>> _batchOverrides = {};

  // --- GETTERS ---

  // IMPORTANTE: retornamos una vista UNMODIFIABLE del mapa interno, no una copia
  // shallow. Así el checkout siempre lee los valores actualizados sin necesidad
  // de recrear el mapa en cada rebuild, evitando inconsistencias con _batchOverrides.
  Map<String, CartItemModel> get items => Map.unmodifiable(_items);

  int get itemCount => _items.length;

  String? get selectedClientId => _selectedClientId;
  String? get selectedClientName => _selectedClientName;
  int get saldoActualCliente => _saldoActualCliente;
  int get puntosAUsar => _puntosAUsar;
  String get paymentMethod => _paymentMethod;
  String? get selectedWarehouseId => _selectedWarehouseId;

  /// Overrides de lotes asignados manualmente (cartKey → lista dinámica).
  /// El checkout los lee y escribe a través de [setBatchOverride] / [clearBatchOverride].
  Map<String, List<dynamic>> get batchOverrides =>
      Map.unmodifiable(_batchOverrides);

  double get totalAmount {
    var total = 0.0;
    _items.forEach((_, item) => total += item.totalItemPrice);
    return total;
  }

  // --- SETTERS DE CONFIGURACIÓN ---

  void setClient(String? id, String? name, int saldo) {
    _selectedClientId = id;
    _selectedClientName = name;
    _saldoActualCliente = saldo;
    _puntosAUsar = 0;
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

  /// Cambiar de almacén limpia todos los overrides de lotes porque los lotes
  /// son específicos a cada almacén. El usuario tendrá que reasignar si quiere.
  void setWarehouse(String? id) {
    if (id != _selectedWarehouseId) {
      _batchOverrides.clear();
    }
    _selectedWarehouseId = id;
    notifyListeners();
  }

  // --- GESTIÓN DE LOTES ---

  /// Guarda el override de lotes para un ítem. Llamado desde el checkout
  /// cuando el usuario confirma la asignación en el _BatchEditSheet.
  void setBatchOverride(String cartKey, List<dynamic> assignments) {
    _batchOverrides[cartKey] = assignments;
    notifyListeners();
  }

  /// Elimina el override de un ítem (vuelve a FEFO automático).
  void clearBatchOverride(String cartKey) {
    _batchOverrides.remove(cartKey);
    notifyListeners();
  }

  /// Retorna true si el ítem tiene un override manual guardado.
  bool hasBatchOverride(String cartKey) => _batchOverrides.containsKey(cartKey);

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
      // Si se suma más cantidad al mismo ítem, el override previo ya no es
      // válido porque la suma de lotes no cuadraría con la nueva cantidad.
      _batchOverrides.remove(key);
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
          // Propagamos si el producto gestiona lotes para que el checkout
          // pueda mostrar el chip de edición sin acceder al ProductModel.
          usesBatches: product.usesBatches,
        ),
      );
    }
    notifyListeners();
  }

  void setQuantity(String cartKey, int quantity) {
    if (!_items.containsKey(cartKey)) return;
    if (quantity <= 0) {
      _items.remove(cartKey);
      _batchOverrides.remove(cartKey); // limpiamos override huérfano
    } else {
      _items.update(cartKey, (existing) {
        existing.quantity =
            quantity > existing.availableStock
                ? existing.availableStock
                : quantity;
        return existing;
      });
      // Si la cantidad cambió, el override de lotes ya no cuadra → borramos.
      _batchOverrides.remove(cartKey);
    }
    notifyListeners();
  }

  void removeProduct(String key) {
    _items.remove(key);
    _batchOverrides.remove(key); // siempre limpiamos el override asociado
    notifyListeners();
  }

  void clearPos() {
    _items.clear();
    _batchOverrides.clear();
    _selectedClientId = null;
    _selectedClientName = null;
    _saldoActualCliente = 0;
    _puntosAUsar = 0;
    _paymentMethod = 'EFECTIVO';
    // El almacén se mantiene para comodidad en la siguiente venta.
    notifyListeners();
  }
}
