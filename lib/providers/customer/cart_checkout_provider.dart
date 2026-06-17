import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/services/customer/cart_checkout_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartCheckoutProvider extends ChangeNotifier {
  final CartCheckoutService _service = CartCheckoutService();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isSending = false;
  bool _isVerifyingStock = false;
  bool _isLoadingAddress = false;
  Map<String, dynamic>? _defaultAddress;

  bool _usePoints = false;

  bool get isSending => _isSending;
  bool get isVerifyingStock => _isVerifyingStock;
  bool get isLoadingAddress => _isLoadingAddress;
  bool get usePoints => _usePoints;
  Map<String, dynamic>? get defaultAddress => _defaultAddress;

  void toggleUsePoints() {
    _usePoints = !_usePoints;
    notifyListeners();
  }

  Future<void> loadAddress() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _isLoadingAddress = true;
    notifyListeners();

    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .single();

      _defaultAddress = await _service.fetchDefaultAddress(profile['id']);
    } catch (e) {
      debugPrint('Error cargando dirección: $e');
    } finally {
      _isLoadingAddress = false;
      notifyListeners();
    }
  }

  double wholesalePriceOf(CartItemModel item) {
    return item.wholesalePrice ?? item.product.wholesalePrice ?? item.unitPrice;
  }

  double maxDiscountSoles(CartProvider cart) {
    double total = 0;
    for (final item in cart.selectedItems) {
      final wPrice = wholesalePriceOf(item);
      final discountPerItem = item.unitPrice - wPrice;
      if (discountPerItem > 0) {
        total += discountPerItem * item.quantity;
      }
    }
    return total;
  }

  int calculateApplicablePoints(
    CartProvider cart,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    if (!_usePoints) return 0;
    final maxSoles = maxDiscountSoles(cart);
    final neededPoints = (maxSoles / pointsToSolesRatio).ceil();
    return saldoPuntos >= neededPoints ? neededPoints : saldoPuntos;
  }

  double calculateFinalTotal(
    CartProvider cart,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    final discountSoles =
        calculateApplicablePoints(cart, pointsToSolesRatio, saldoPuntos) *
        pointsToSolesRatio;
    return cart.selectedTotalAmount - discountSoles;
  }

  int getAppliedPointsForItem(
    CartItemModel item,
    CartProvider cart,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    if (!_usePoints) return 0;
    if (!item.isSelected) return 0;
    final wPrice = wholesalePriceOf(item);
    final discountPerItemSoles = item.unitPrice - wPrice;
    if (discountPerItemSoles <= 0) return 0;

    final usedPoints = calculateApplicablePoints(
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    if (usedPoints <= 0) return 0;

    final totalDiscountPossible = maxDiscountSoles(cart);
    if (totalDiscountPossible <= 0) return 0;

    final itemDiscountTotal = discountPerItemSoles * item.quantity;
    final proportion = itemDiscountTotal / totalDiscountPossible;
    return (usedPoints * proportion).round();
  }

  Future<List<String>> verifyStock(
    List<CartItemModel> itemsToBuy,
    String warehouseId,
  ) async {
    _isVerifyingStock = true;
    notifyListeners();
    List<String> outOfStockMessages = [];

    try {
      final variantIds =
          itemsToBuy
              .map((i) => i.variantId)
              .where((id) => id != null)
              .cast<String>()
              .toList();

      final stockMap = await _service.fetchStockForVariants(
        warehouseId,
        variantIds,
      );

      for (final item in itemsToBuy) {
        if (item.variantId == null) continue;
        final currentStock = stockMap[item.variantId] ?? 0;
        if (currentStock < item.quantity) {
          final variantLabel =
              item.variantLabel != null ? ' - ${item.variantLabel}' : '';
          outOfStockMessages.add(
            '• ${item.product.name}$variantLabel (Stock disponible: $currentStock, Tu pedido: ${item.quantity})',
          );
        }
      }
    } catch (e) {
      debugPrint('Error verificando stock: $e');
      outOfStockMessages.add(
        'Error al verificar stock. Por favor, intenta de nuevo.',
      );
    } finally {
      _isVerifyingStock = false;
      notifyListeners();
    }
    return outOfStockMessages;
  }

  Future<Map<String, dynamic>?> processCheckout({
    required CartProvider cart,
    required WalletProvider wallet,
    required AppConfigProvider config,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'error': 'AUTH', 'message': 'Debes iniciar sesión para hacer un pedido.'};
    }

    final itemsToBuy = cart.selectedItems.cast<CartItemModel>().toList();
    if (itemsToBuy.isEmpty) {
      return {'error': 'EMPTY', 'message': 'No hay productos seleccionados.'};
    }

    _isSending = true;
    notifyListeners();

    try {
      final warehouseId = await _service.getActiveWarehouseId();
      if (warehouseId == null) throw Exception('No hay almacenes activos.');

      final outOfStockMessages = await verifyStock(itemsToBuy, warehouseId);
      if (outOfStockMessages.isNotEmpty) {
        _isSending = false;
        notifyListeners();
        return {'error': 'STOCK', 'messages': outOfStockMessages};
      }

      final profileResp =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
      final customerId = profileResp?['id'];

      final saldoPuntos = wallet.balance ?? 0;
      final earningRate = config.getDouble('points_earning_rate', 0.03);
      final pointsToSolesRatio = config.getDouble(
        'points_to_soles_ratio',
        0.01,
      );

      final puntosUsados =
          customerId != null
              ? calculateApplicablePoints(cart, pointsToSolesRatio, saldoPuntos)
              : 0;
      final totalAPagar = calculateFinalTotal(
        cart,
        pointsToSolesRatio,
        saldoPuntos,
      );
      final puntosAGanar =
          (totalAPagar * earningRate / pointsToSolesRatio).toInt();

      double totalProfit = 0.0;
      for (final item in itemsToBuy) {
        totalProfit += (item.unitPrice - item.unitCost) * item.quantity;
      }

      final orderId = await _service.processOrder(
        customerId: customerId,
        totalAmount: totalAPagar,
        pointsUsed: puntosUsados,
        pointsEarned: puntosAGanar,
        totalProfit: totalProfit,
        warehouseId: warehouseId,
        itemsToBuy: itemsToBuy,
      );

      cart.removeSelectedItems();

      return {
        'success': true,
        'orderId': orderId,
        'totalAPagar': totalAPagar,
        'puntosUsados': puntosUsados,
        'itemsToBuy': itemsToBuy,
      };
    } catch (e) {
      _isSending = false;
      notifyListeners();
      debugPrint('Error confirming order: $e');
      final errStr = e.toString().toLowerCase();
      String errorMsg = 'Ocurrió un error inesperado al confirmar el pedido.';
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        errorMsg = 'Sin conexión a internet.';
      }
      return {'error': 'EXCEPTION', 'message': errorMsg};
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
