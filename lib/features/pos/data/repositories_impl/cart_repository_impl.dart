import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cart_repository.dart';
import 'package:inventory_store_app/features/pos/data/models/cart_item_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

@LazySingleton(as: CartRepository)
class CartRepositoryImpl implements CartRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _getCartKey(String cartType) => 'local_cart_$cartType';

  @override
  Future<Either<Failure, Map<String, CartItemEntity>>> loadLocalCart(
    String cartType,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartString = prefs.getString(_getCartKey(cartType));
      if (cartString != null) {
        final Map<String, dynamic> decodedMap = json.decode(cartString);
        final map = decodedMap.map(
          (key, value) =>
              MapEntry(key, CartItemModel.fromJson(value).toEntity()),
        );
        return right(map);
      }
      return right({});
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveLocalCart(
    String cartType,
    Map<String, CartItemEntity> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert Entity to Model for serialization
      // Note: we'd need CartItemModel.fromEntity if it existed, but we can do it manually or assume CartItemModel constructor takes a ProductEntity and maps it.
      // Actually CartItemModel constructor takes ProductEntity and other params. Let's map it.
      final modelsMap = items.map((key, item) {
        // We recreate a dummy ProductEntity with only the id and name since that's what CartItemModel needs minimally, OR we just use the JSON directly.
        // Wait, the current CartItemModel constructor requires a full ProductEntity.
        // Let's create a map to JSON directly from the entity for local storage.
        return MapEntry(key, {
          'product': {
            'id': item.productId,
            'name': item.productName,
            'unit_cost': item.unitCost,
            'sale_price': item.unitPrice,
            'uses_batches': item.usesBatches,
          },
          'quantity': item.quantity,
          'variantId': item.variantId,
          'variantLabel': item.variantLabel,
          'unitPrice': item.unitPrice,
          'wholesalePrice': item.wholesalePrice,
          'imageUrl': item.imageUrl,
          'sku': item.sku,
          'availableStock': item.availableStock,
          'cartKey': item.cartKey,
          'usesBatches': item.usesBatches,
          'isSelected': item.isSelected,
        });
      });

      final encodedMap = json.encode(modelsMap);
      await prefs.setString(_getCartKey(cartType), encodedMap);
      return right(unit);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearLocalCart(String cartType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getCartKey(cartType));
      return right(unit);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

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

  @override
  Future<Either<Failure, Map<String, CartItemEntity>>> syncCloudCart(
    String cartType,
    String profileId,
    Map<String, CartItemEntity> localItems,
  ) async {
    try {
      if (cartType == 'pos') {
        return right(localItems);
      }
      final cartId = await _getOrCreateCartId(profileId);
      if (cartId == null) {
        return left(
          const ServerFailure(
            message: 'No se pudo crear/obtener carrito en la nube.',
          ),
        );
      }

      // 1. Si hay items locales, sincronizamos hacia la nube (overwrite)
      // En una implementación real, podría haber merge, pero siguiendo la lógica legacy:
      await _supabase.from('cart_items').delete().eq('cart_id', cartId);

      if (localItems.isNotEmpty) {
        final itemsToInsert =
            localItems.values.map((item) {
              final vid = item.variantId;
              return {
                'cart_id': cartId,
                'product_id': item.productId,
                'variant_id': (vid == null || vid.isEmpty) ? null : vid,
                'quantity': item.quantity,
                'is_selected': item.isSelected,
              };
            }).toList();

        await _supabase.from('cart_items').insert(itemsToInsert);
      }

      // 2. Descargamos la nube para obtener los datos frescos de productos (precios, stock, etc.)
      final itemsResponse = await _supabase
          .from('cart_items')
          .select('''
            quantity,
            variant_id,
            is_selected,
            products (
              id, name, description, unit_cost, sale_price,
              wholesale_price, wholesale_min_quantity, is_active, uses_batches,
              product_images (id, product_id, image_url, is_main, display_order)
            ),
            product_variants (
              id, product_id, sku, barcode,
              unit_cost, sale_price, wholesale_price,
              wholesale_min_quantity, is_active, reorder_point,
              product_images (id, product_id, variant_id, image_url, is_main, display_order),
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

      final Map<String, CartItemEntity> cloudItems = {};

      for (final row in List<Map<String, dynamic>>.from(itemsResponse)) {
        final rawProduct = row['products'];
        final productJson =
            rawProduct is Map
                ? rawProduct
                : (rawProduct is List && rawProduct.isNotEmpty
                    ? rawProduct.first
                    : null);

        if (productJson == null) continue;

        final product =
            ProductModel.fromJson(
              Map<String, dynamic>.from(productJson as Map),
            ).toEntity();
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

        ProductVariantModel? variantModel;
        if (variantJson != null) {
          try {
            variantModel = ProductVariantModel.fromJson(
              Map<String, dynamic>.from(variantJson as Map),
            );
          } catch (e) {
            debugPrint('CartRepositoryImpl: error parseando variante: $e');
          }
        }

        final variant = variantModel?.toEntity();
        final finalVariantId = variant?.id ?? rawVariantId;
        final cartKey = CartItemModel.buildKey(product.id, finalVariantId);

        final effectiveUnitCost =
            ((variant?.unitCost ?? 0) > 0)
                ? variant!.unitCost!
                : product.unitCost;

        final entity = CartItemEntity(
          productId: product.id,
          productName: product.name,
          quantity: qty,
          variantId: finalVariantId,
          variantLabel:
              variant?.label ??
              (finalVariantId != null ? 'Variante seleccionada' : null),
          unitPrice: variant?.salePrice ?? product.salePrice,
          unitCost: effectiveUnitCost,
          wholesalePrice: variant?.wholesalePrice ?? product.wholesalePrice,
          imageUrl:
              (variant != null && variant.images.isNotEmpty)
                  ? variant.images.first.imageUrl
                  : product.primaryImageUrl,
          sku: variant?.sku,
          availableStock: 999, // Legacy hardcode
          cartKey: cartKey,
          usesBatches: product.usesBatches,
          isSelected: isSelected,
        );

        cloudItems[cartKey] = entity;
      }

      return right(cloudItems);
    } catch (e) {
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearCloudCart(
    String cartType,
    String profileId,
  ) async {
    try {
      if (cartType == 'pos') {
        return right(unit);
      }
      final cartId = await _getOrCreateCartId(profileId);
      if (cartId == null) {
        return left(
          const ServerFailure(
            message: 'No se pudo crear/obtener carrito en la nube.',
          ),
        );
      }
      await _supabase.from('cart_items').delete().eq('cart_id', cartId);
      return right(unit);
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
