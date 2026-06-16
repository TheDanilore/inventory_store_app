import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';

class CartCloudService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Obtener profileId de forma segura ────────────────────────────────────
  Future<String?> _getProfileId(String authUserId) async {
    for (int i = 0; i < 3; i++) {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      if (profile != null) {
        return profile['id'] as String?;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  // ── Obtener o crear cartId de forma segura ────────────────────────────────
  Future<String?> _getOrCreateCartId(String profileId) async {
    final existing =
        await _supabase
            .from('shopping_carts')
            .select('id')
            .eq('profile_id', profileId)
            .maybeSingle();

    if (existing != null) {
      return existing['id'] as String?;
    }

    final created =
        await _supabase
            .from('shopping_carts')
            .insert({'profile_id': profileId})
            .select('id')
            .maybeSingle();
    return created?['id'] as String?;
  }

  // ── Descargar carrito desde la nube ──────────────────────────────────────
  Future<Map<String, CartItemModel>?> downloadCloudCart(
    String authUserId,
  ) async {
    try {
      final profileId = await _getProfileId(authUserId);
      if (profileId == null) {
        debugPrint('CartCloudService: perfil no encontrado.');
        return null;
      }

      final cartId = await _getOrCreateCartId(profileId);
      if (cartId == null) {
        debugPrint('CartCloudService: no se pudo obtener o crear el carrito.');
        return null;
      }

      // Optimización: traer solo (id, image_url, is_main) en product_images para ahorrar Egress
      final itemsResponse = await _supabase
          .from('cart_items')
          .select('''
            quantity,
            variant_id,
            is_selected,
            products (
              id, name, description, unit_cost, sale_price,
              wholesale_price, wholesale_min_quantity, is_active,
              product_images (id, image_url, is_main, display_order)
            ),
            product_variants (
              id, product_id, sku, barcode,
              unit_cost, sale_price, wholesale_price,
              wholesale_min_quantity, is_active, reorder_point,
              product_images (id, image_url, is_main, display_order),
              variant_attribute_values (
                attribute_value_id,
                attribute_values (
                  id, value,
                  attributes ( id, name )
                )
              )
            )
          ''')
          .eq('cart_id', cartId);

      final Map<String, CartItemModel> cloudItems = {};

      for (final row in List<Map<String, dynamic>>.from(itemsResponse)) {
        final rawProduct = row['products'];
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
            debugPrint('CartCloudService: error parseando variante: $e');
          }
        }

        final finalVariantId = variant?.id ?? rawVariantId;
        final cartKey = CartItemModel.buildKey(product.id, finalVariantId);

        final effectiveUnitCost =
            ((variant?.unitCost ?? 0) > 0)
                ? variant!.unitCost!
                : product.unitCost;

        cloudItems[cartKey] = CartItemModel(
          product: product,
          quantity: qty,
          variantId: finalVariantId,
          variantLabel:
              variant?.label ??
              (finalVariantId != null ? 'Variante seleccionada' : null),
          unitPrice: variant?.salePrice ?? product.salePrice,
          unitCost: effectiveUnitCost,
          wholesalePrice: variant?.wholesalePrice ?? product.wholesalePrice,
          imageUrl: variant?.primaryImageUrl ?? product.primaryImageUrl,
          sku: variant?.sku,
          availableStock:
              999, // Stock se actualizará en background en la UI si hace falta
          cartKey: cartKey,
          isSelected: isSelected,
        );
      }
      return cloudItems;
    } catch (e) {
      debugPrint('CartCloudService - Error descargando carrito: $e');
      throw Exception('No se pudo descargar el carrito de la nube');
    }
  }

  // ── Sincronizar hacia Supabase ────────────────────────────────────────────
  Future<void> syncToCloud(
    String authUserId,
    Map<String, CartItemModel> items,
  ) async {
    try {
      final profileId = await _getProfileId(authUserId);
      if (profileId == null) return;

      final cartId = await _getOrCreateCartId(profileId);
      if (cartId == null) return;

      // Borramos lo que hay actualmente en el carrito de este usuario
      await _supabase.from('cart_items').delete().eq('cart_id', cartId);

      if (items.isNotEmpty) {
        final itemsToInsert =
            items.values.map((item) {
              final vid = item.variantId;
              return {
                'cart_id': cartId,
                'product_id': item.product.id,
                'variant_id': (vid == null || vid.isEmpty) ? null : vid,
                'quantity': item.quantity,
                'is_selected': item.isSelected,
              };
            }).toList();

        await _supabase.from('cart_items').insert(itemsToInsert);
      }
    } catch (e) {
      debugPrint('CartCloudService - Error sincronizando a la nube: $e');
      throw Exception('Fallo en la sincronización a la nube.');
    }
  }
}
