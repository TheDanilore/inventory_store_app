import 'dart:convert';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:inventory_store_app/features/cart/data/models/cart_item_model.dart';
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
    } catch (e, st) {
      developer.log(
        'Error en loadLocalCart',
        error: e,
        stackTrace: st,
        name: 'CartRepo',
      );
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
    } catch (e, st) {
      developer.log(
        'Error en saveLocalCart',
        error: e,
        stackTrace: st,
        name: 'CartRepo',
      );
      return left(Failure.from(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearLocalCart(String cartType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getCartKey(cartType));
      return right(unit);
    } catch (e, st) {
      developer.log(
        'Error en clearLocalCart',
        error: e,
        stackTrace: st,
        name: 'CartRepo',
      );
      return left(Failure.from(e));
    }
  }

  /// Traduce el auth_user_id (Supabase Auth UUID) o el profiles.id real al FK destino.
  Future<String?> _getProfileId(String identifier) async {
    // Búsqueda resiliente: valida si es auth_user_id o directamente profiles.id
    final profile =
        await _supabase
            .from('profiles')
            .select('id')
            .or('auth_user_id.eq.$identifier,id.eq.$identifier')
            .maybeSingle();
    if (profile != null) return profile['id'] as String?;

    // Respaldo defensivo si RLS restringe profiles pero el identifier ya es el FK en shopping_carts
    final cart =
        await _supabase
            .from('shopping_carts')
            .select('profile_id')
            .eq('profile_id', identifier)
            .maybeSingle();
    return cart?['profile_id'] as String?;
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

      // 1. Sincronización atómica mediante RPC (Reemplaza 5 llamadas HTTP)
      final itemsToInsert =
          localItems.values.map((item) {
            final vid = item.variantId;
            return {
              'product_id': item.productId,
              'variant_id': (vid == null || vid.isEmpty) ? null : vid,
              'quantity': item.quantity.toString(),
              'is_selected': item.isSelected.toString(),
            };
          }).toList();

      final responseRpc = await _supabase.rpc(
        'sync_cloud_cart_rpc',
        params: {'p_auth_user_id': profileId, 'p_items': itemsToInsert},
      );

      final String cartId = responseRpc.toString();

      // 2. Descargamos la nube optimizando Data Egress: seleccionando campos mínimos e incluyendo lotes de stock
      final itemsResponse = await _supabase
          .from('cart_items')
          .select('''
            quantity,
            variant_id,
            is_selected,
            products (
              id, name, is_active, uses_batches, stock_control,
              product_images (id, product_id, image_url, is_main, display_order),
              warehouse_stock_batches (available_quantity, variant_id)
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
          } catch (e, st) {
            developer.log(
              'Error parseando variante en syncCloudCart',
              error: e,
              stackTrace: st,
              name: 'CartRepo',
            );
          }
        }

        final variant = variantModel?.toEntity();
        final finalVariantId = variant?.id ?? rawVariantId;
        final cartKey = CartItemModel.buildKey(product.id, finalVariantId);

        final effectiveUnitCost =
            ((variant?.unitCost ?? 0) > 0)
                ? variant!.unitCost!
                : (product.defaultVariant?.unitCost ?? 0.0);

        // Cálculo de stock real a partir de lotes e inventarios
        int calculatedStock = 0;
        if (productJson['warehouse_stock_batches'] is List) {
          final batches = productJson['warehouse_stock_batches'] as List;
          for (final b in batches) {
            if (b is Map) {
              final bVarId = b['variant_id'] as String?;
              if (finalVariantId == null ||
                  bVarId == null ||
                  bVarId == finalVariantId) {
                calculatedStock +=
                    (b['available_quantity'] as num?)?.toInt() ?? 0;
              }
            }
          }
        }
        if (calculatedStock <= 0 && product.totalStock > 0) {
          calculatedStock = product.totalStock;
        }
        final finalStock =
            (calculatedStock == 0 && !product.stockControl)
                ? 999
                : calculatedStock;

        final entity = CartItemEntity(
          productId: product.id,
          productName: product.name,
          quantity: qty,
          variantId: finalVariantId,
          variantLabel:
              variant?.label ??
              (finalVariantId != null ? 'Variante seleccionada' : null),
          unitPrice: variant?.salePrice ?? product.displaySalePrice ?? 0.0,
          unitCost: effectiveUnitCost,
          wholesalePrice: variant?.wholesalePrice,
          imageUrl:
              (variant != null && variant.images.isNotEmpty)
                  ? variant.images.first.imageUrl
                  : product.primaryImageUrl,
          sku: variant?.sku,
          availableStock:
              finalStock, // Reemplazo de hardcode legacy por stock verificado
          cartKey: cartKey,
          usesBatches: product.usesBatches,
          isSelected: isSelected,
        );

        cloudItems[cartKey] = entity;
      }

      return right(cloudItems);
    } catch (e, st) {
      developer.log(
        'Error en syncCloudCart',
        error: e,
        stackTrace: st,
        name: 'CartRepo',
      );
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

      // 1. Intento de limpieza atómica mediante RPC optimizado (1 sola llamada de red)
      try {
        await _supabase.rpc(
          'clear_cloud_cart_rpc',
          params: {'p_user_id': profileId},
        );
        return right(unit);
      } catch (rpcError) {
        developer.log(
          'RPC clear_cloud_cart_rpc no disponible o falló. Usando respaldo resiliente.',
          error: rpcError,
          name: 'CartRepo',
        );
      }

      // 2. Respaldo resiliente: Traduce auth_user_id o valida profiles.id real sin fallar con "Perfil no encontrado".
      final realProfileId = await _getProfileId(profileId);
      if (realProfileId == null) {
        return left(const NotFoundFailure(message: 'Perfil no encontrado.'));
      }
      final existing =
          await _supabase
              .from('shopping_carts')
              .select('id')
              .eq('profile_id', realProfileId)
              .maybeSingle();

      if (existing == null) {
        // No existe carrito en BD, no es necesario crearlo solo para vaciarlo
        return right(unit);
      }
      final cartId = existing['id'] as String;
      await _supabase.from('cart_items').delete().eq('cart_id', cartId);
      return right(unit);
    } catch (e, st) {
      developer.log(
        'Error en clearCloudCart',
        error: e,
        stackTrace: st,
        name: 'CartRepo',
      );
      return left(Failure.from(e));
    }
  }
}
