import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';

class CartLocalService {
  static const String _cartKey = 'local_cart';

  Future<Map<String, CartItemModel>> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString(_cartKey);
      if (cartString != null) {
        final Map<String, dynamic> decodedMap = json.decode(cartString);
        return decodedMap.map(
          (key, value) => MapEntry(key, CartItemModel.fromJson(value)),
        );
      }
    } catch (e) {
      debugPrint('Error al cargar el carrito local: $e');
    }
    return {};
  }

  Future<void> saveCart(Map<String, CartItemModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedMap = json.encode(
        items.map((key, value) => MapEntry(key, value.toJson())),
      );
      await prefs.setString(_cartKey, encodedMap);
    } catch (e) {
      debugPrint('Error al guardar el carrito local: $e');
    }
  }

  Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cartKey);
    } catch (e) {
      debugPrint('Error al limpiar el carrito local: $e');
    }
  }
}
