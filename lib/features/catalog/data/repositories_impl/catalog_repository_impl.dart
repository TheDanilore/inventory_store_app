import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/variant_draft_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/category_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/active_ingredient_model.dart';

@LazySingleton(as: CatalogRepository)
class CatalogRepositoryImpl implements CatalogRepository {
  final SupabaseClient _supabase;

  CatalogRepositoryImpl(this._supabase);

  // Helper para manejar excepciones repetitivas
  Either<Failure, T> _handleError<T>(Object e) {
    if (e is PostgrestException) {
      return left(Failure.from('Error de BD: '));
    }
    return left(Failure.from('Ocurrió un error inesperado: '));
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories({bool activeOnly = false}) async {
    try {
      var query = _supabase.from('categories').select('id, name, description, is_active, created_at, products:products(count)');
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('name');
      final models = List<Map<String, dynamic>>.from(response).map(CategoryModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, ({List<ProductEntity> products, int totalCount})>> getProducts({
    String? searchQuery,
    String? categoryId,
    bool? isActive,
    int limit = 20,
    int offset = 0,
    bool sortByPriceAsc = true,
  }) async {
    try {
      var query = _supabase.from('products').select(
        'id, name, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, description, category_id, details, created_at, updated_at, stock_control, uses_batches, product_type, product_images(*), categories(name)'
      );

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%${searchQuery.trim()}%');
      }

      var transformQuery = query.order('name');
      transformQuery = transformQuery.range(offset, offset + limit - 1);
      final response = await transformQuery.count(CountOption.exact);

      final models = List<Map<String, dynamic>>.from(response.data).map(ProductModel.fromJson).toList();
      final entities = models.map((m) => m.toEntity()).toList();
      return right((products: entities, totalCount: response.count));
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, ProductEntity?>> getProductById(String id) async {
    try {
      final response = await _supabase.from('products').select(
        'id, name, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, description, category_id, details, created_at, updated_at, stock_control, uses_batches, product_type, product_images(*), categories(name), product_variants(id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))), warehouse_stock_batches(*)'
      ).eq('id', id).maybeSingle();

      if (response == null) return right(null);
      final model = ProductModel.fromJson(response);
      return right(model.toEntity());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getProductStock({List<String>? productIds}) async {
    try {
      var query = _supabase.from('warehouse_stock_batches').select('product_id, available_quantity');
      if (productIds != null && productIds.isNotEmpty) {
        query = query.inFilter('product_id', productIds);
      }
      final response = await query;
      final map = <String, int>{};
      for (final row in response) {
        final pId = row['product_id'] as String?;
        final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
        if (pId != null) {
          map[pId] = (map[pId] ?? 0) + qty;
        }
      }
      return right(map);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    try {
      await _supabase
          .from('products')
          .update({'is_active': isActive})
          .eq('id', productId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, ProductVariantEntity?>> getVariantById(String variantId) async {
    try {
      final response = await _supabase.from('product_variants').select(
        'id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))'
      ).eq('id', variantId).maybeSingle();

      if (response == null) return right(null);
      final model = ProductVariantModel.fromJson(response);
      return right(model.toEntity());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getStockByVariant(String productId) async {
    try {
      final response = await _supabase.from('warehouse_stock_batches')
          .select('variant_id, available_quantity')
          .eq('product_id', productId);
          
      final map = <String, int>{};
      for (final row in response) {
        final vId = row['variant_id'] as String?;
        final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
        if (vId != null) {
          map[vId] = (map[vId] ?? 0) + qty;
        }
      }
      return right(map);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<VariantDraftModel>>> getVariantsDrafts(String productId) async {
    try {
      final response = await _supabase.from('product_variants').select(
        'id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))'
      ).eq('product_id', productId).eq('is_active', true).order('created_at');
      
      final drafts = List<Map<String, dynamic>>.from(response).map((json) {
        final variant = ProductVariantModel.fromJson(json);
        return VariantDraftModel.fromVariant(variant);
      }).toList();
      return right(drafts);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getAttributes() async {
    try {
      final response = await _supabase.from('attributes').select('id, name, attribute_values(id, value)').order('name');
      return right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getProductIngredients(String productId) async {
    try {
      final response = await _supabase.from('product_active_ingredients')
          .select('ingredient_id, concentration, unit, active_ingredients(name)')
          .eq('product_id', productId);
      return right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<ActiveIngredientEntity>>> searchIngredients(String term) async {
    try {
      final response = await _supabase.rpc('search_ingredients_unaccent', params: {'search_term': term});
      final models = List<Map<String, dynamic>>.from(response).map(ActiveIngredientModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, ActiveIngredientEntity>> createIngredient(String name) async {
    try {
      final response = await _supabase.from('active_ingredients').insert({'name': name.trim()}).select().single();
      return right(ActiveIngredientModel.fromJson(response).toEntity());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<ProductImageEntity>>> getProductImages(String productId) async {
    try {
      final response = await _supabase.from('product_images').select().eq('product_id', productId).order('display_order');
      final models = List<Map<String, dynamic>>.from(response).map(ProductImageModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, String?>> uploadImageToStorage(Uint8List bytes, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$folder/$fileName';
      await _supabase.storage.from('products').uploadBinary(path, bytes);
      final publicUrl = _supabase.storage.from('products').getPublicUrl(path);
      return right(publicUrl);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteProductImage(String id, String imageUrl) async {
    try {
      await _supabase.from('product_images').delete().eq('id', id);
      final uri = Uri.tryParse(imageUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final pathIdx = uri.pathSegments.indexOf('products');
        if (pathIdx != -1 && pathIdx + 1 < uri.pathSegments.length) {
          final filePath = uri.pathSegments.sublist(pathIdx + 1).join('/');
          await _supabase.storage.from('products').remove([filePath]);
        }
      }
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> syncProductImages(List<Map<String, dynamic>> payload) async {
    try {
      await _supabase.from('product_images').upsert(payload, onConflict: 'id');
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteVariant(String variantId) async {
    try {
      await _supabase.from('product_variants').delete().eq('id', variantId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deactivateVariant(String variantId) async {
    try {
      await _supabase.from('product_variants').update({'is_active': false}).eq('id', variantId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, bool>> hasVariantSales(String variantId) async {
    try {
      final count = await _supabase.from('order_items').select().eq('variant_id', variantId).count(CountOption.exact);
      return right(count.count > 0);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> clearVariantImages(String variantId) async {
    try {
      await _supabase.from('product_images').update({'variant_id': null}).eq('variant_id', variantId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> clearProductIngredients(String productId) async {
    try {
      await _supabase.from('product_active_ingredients').delete().eq('product_id', productId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> insertProductIngredient(Map<String, dynamic> payload) async {
    try {
      await _supabase.from('product_active_ingredients').insert(payload);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, bool>> checkWishlistState(String productId, String profileId) async {
    try {
      final res = await _supabase.from('wishlist_items').select('id').eq('profile_id', profileId).eq('product_id', productId).maybeSingle();
      return right(res != null);
    } catch (e) {
      return _handleError(e);
    }
  }


  @override
  Future<Either<Failure, CategoryEntity>> createCategory({required String name, String? description, required bool isActive}) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? profileId;
      if (authUserId != null) {
        final p = await _supabase.from('profiles').select('id').eq('auth_user_id', authUserId).maybeSingle();
        profileId = p?['id'] as String?;
      }
      final response = await _supabase.from('categories').insert({
        'name': name.trim(),
        'description': description?.trim(),
        'is_active': isActive,
        if (profileId != null) 'created_by': profileId,
      }).select().single();
      final model = CategoryModel.fromJson(response);
      return right(model.toEntity());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> updateCategory({required String id, required String name, String? description, required bool isActive}) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? profileId;
      if (authUserId != null) {
        final p = await _supabase.from('profiles').select('id').eq('auth_user_id', authUserId).maybeSingle();
        profileId = p?['id'] as String?;
      }
      await _supabase.from('categories').update({
        'name': name.trim(),
        'description': description?.trim(),
        'is_active': isActive,
        if (profileId != null) 'updated_by': profileId,
      }).eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createAttribute(String name) async {
    try {
      final res = await _supabase.from('attributes').insert({'name': name.trim()}).select().single();
      return right(res);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> updateAttribute(String id, String name) async {
    try {
      await _supabase.from('attributes').update({'name': name.trim()}).eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteAttribute(String id) async {
    try {
      await _supabase.from('attributes').delete().eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createAttributeValue(String attributeId, String value) async {
    try {
      final res = await _supabase.from('attribute_values').insert({'attribute_id': attributeId, 'value': value.trim()}).select().single();
      return right(res);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> updateAttributeValue(String valueId, String value) async {
    try {
      await _supabase.from('attribute_values').update({'value': value.trim()}).eq('id', valueId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteAttributeValue(String valueId) async {
    try {
      await _supabase.from('attribute_values').delete().eq('id', valueId);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> updateIngredient(String id, String name) async {
    try {
      await _supabase.from('active_ingredients').update({'name': name.trim()}).eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> deleteIngredient(String id) async {
    try {
      await _supabase.from('active_ingredients').delete().eq('id', id);
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<ActiveIngredientEntity>>> getIngredients({String? searchQuery, int limit = 20, int offset = 0}) async {
    try {
      var query = _supabase.from('active_ingredients').select();
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.ilike('name', '%%');
      }
      final response = await query.order('name').range(offset, offset + limit - 1);
      final models = List<Map<String, dynamic>>.from(response).map(ActiveIngredientModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, String>> saveProductMaster(ProductEntity product, String? profileId) async {
    try {
      final isUpdating = product.id.isNotEmpty;
      final dataToSave = {
        'name': product.name,
        'unit_cost': product.unitCost,
        'sale_price': product.salePrice,
        'wholesale_price': product.wholesalePrice,
        'wholesale_min_quantity': product.wholesaleMinQuantity,
        'is_active': product.isActive,
        'description': product.description,
        'category_id': product.categoryId,
        'details': product.details,
        'product_type': product.productType,
        'stock_control': product.stockControl,
        'uses_batches': product.usesBatches,
        if (isUpdating && profileId != null) 'updated_by': profileId,
        if (!isUpdating && profileId != null) 'created_by': profileId,
      };

      if (isUpdating) {
        await _supabase.from('products').update(dataToSave).eq('id', product.id);
        return right(product.id);
      } else {
        final res = await _supabase.from('products').insert(dataToSave).select('id').single();
        return right(res['id'] as String);
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, String>> saveVariant({required String productId, required Map<String, dynamic> variantData, String? variantId}) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? profileId;
      if (authUserId != null) {
        final profileResp = await _supabase.from('profiles').select('id').eq('auth_user_id', authUserId).maybeSingle();
        if (profileResp != null) profileId = profileResp['id'] as String;
      }
      final payload = {
        ...variantData,
        'product_id': productId,
        if (variantId != null && profileId != null) 'updated_by': profileId,
        if (variantId == null && profileId != null) 'created_by': profileId,
      };
      if (variantId != null) {
        await _supabase.from('product_variants').update(payload).eq('id', variantId);
        return right(variantId);
      } else {
        final res = await _supabase.from('product_variants').insert(payload).select('id').single();
        return right(res['id'] as String);
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> saveVariantAttributes(String variantId, List<String> attributeValueIds) async {
    try {
      await _supabase.from('variant_attribute_values').delete().eq('variant_id', variantId);
      if (attributeValueIds.isEmpty) return right(null);
      await _supabase.from('variant_attribute_values').insert(
        attributeValueIds.map((valId) => { 'variant_id': variantId, 'attribute_value_id': valId }).toList(),
      );
      return right(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  

  @override
  Future<Either<Failure, String?>> getFirstVariantId(String productId) async {
    try {
      final vResp = await _supabase.from('product_variants').select('id').eq('product_id', productId).limit(1).maybeSingle();
      return right(vResp?['id'] as String?);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, String?>> fetchCurrentProfileId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return right(null);
      final profile = await _supabase.from('profiles').select('id').eq('auth_user_id', user.id).maybeSingle();
      return right(profile?['id'] as String?);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, bool>> toggleWishlist(String productId, String profileId, bool currentState) async {
    try {
      if (currentState) {
        await _supabase.from('wishlist').delete().eq('profile_id', profileId).eq('product_id', productId);
        return right(false);
      } else {
        await _supabase.from('wishlist').insert({'profile_id': profileId, 'product_id': productId});
        return right(true);
      }
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchAdminFinancialData(String productId) async {
    try {
      final response = await _supabase.from('order_items').select('quantity, unit_cost, applied_price, variant_id, orders!inner(status)').eq('product_id', productId).eq('orders.status', 'COMPLETED').limit(500);
      return right(List<Map<String, dynamic>>.from(response as List));
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, ({List<Map<String, dynamic>> stocks, List<Map<String, dynamic>> batches, List<ProductImageModel> images, List<ProductVariantModel> variants, List<Map<String, dynamic>> reviews, List<Map<String, dynamic>> ingredients})>> fetchProductExtraData(String productId) async {
    try {
      final queries = <Future<dynamic>>[
        _supabase.from('warehouse_stock_batches').select('id, available_quantity, variant_id, warehouse_id, batch_number, expiry_date, warehouses(name)').eq('product_id', productId).gt('available_quantity', 0).order('expiry_date', ascending: true, nullsFirst: false),
        _supabase.from('product_images').select('id, product_id, variant_id, image_url, display_order, is_main').eq('product_id', productId).order('display_order', ascending: true),
        _supabase.from('product_variants').select('id, product_id, sku, variant_attribute_values(attribute_values(id, value, attributes(name))), product_images(id, image_url, variant_id), sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, unit_cost').eq('product_id', productId).eq('is_active', true).order('created_at', ascending: true),
        _supabase.from('product_reviews').select('rating, comment, user_name, created_at').eq('product_id', productId).order('created_at', ascending: false).limit(50),
        _supabase.from('product_active_ingredients').select('concentration, unit, active_ingredients(id, name, description)').eq('product_id', productId),
      ];

      final results = await Future.wait(queries);

      final rawStocks = results[0] as List<dynamic>;
      final aggregatedStocks = <String, Map<String, dynamic>>{};
      final validBatches = <Map<String, dynamic>>[];

      for (final row in rawStocks) {
        final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
        if (stock > 0) {
          validBatches.add(Map<String, dynamic>.from(row as Map));
          final wId = row['warehouse_id']?.toString() ?? 'unknown';
          final vId = row['variant_id']?.toString() ?? 'none';
          final key = '${wId}_$vId';
          if (aggregatedStocks.containsKey(key)) {
            aggregatedStocks[key]!['available_quantity'] = (aggregatedStocks[key]!['available_quantity'] as int) + stock;
          } else {
            aggregatedStocks[key] = {
              'warehouse_id': row['warehouse_id'],
              'variant_id': row['variant_id'],
              'warehouses': row['warehouses'],
              'available_quantity': stock,
            };
          }
        }
      }

      return right((
        stocks: aggregatedStocks.values.toList(),
        batches: validBatches,
        images: (results[1] as List).map((e) => ProductImageModel.fromJson(Map<String, dynamic>.from(e))).toList(),
        variants: (results[2] as List).map((e) => ProductVariantModel.fromJson(Map<String, dynamic>.from(e))).toList(),
        reviews: List<Map<String, dynamic>>.from(results[3] as List),
        ingredients: List<Map<String, dynamic>>.from(results[4] as List),
      ));
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  
  @override
  Future<Either<Failure, Map<String, int>>> loadStockByVariant(String productId) async {
    try {
      final response = await _supabase.from('product_stock_summary').select('variant_id, total_stock').eq('product_id', productId);
      final map = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final vid = row['variant_id'] as String?;
        final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
        if (vid != null) map[vid] = stock;
      }
      return right(map);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> loadActiveVariants(String productId) async {
    try {
      final response = await _supabase.from('product_variants').select('*, product_images(*), variant_attribute_values(attribute_values(id, value, attributes(id, name)))').eq('product_id', productId).eq('is_active', true).order('sku');
      return right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, Map<String, List<ProductVariantModel>>>> fetchVariantsByProductIds(List<String> productIds) async {
    try {
      if (productIds.isEmpty) return right({});
      final response = await _supabase.from('product_variants').select('*, product_images(id, image_url, is_main, display_order), variant_attribute_values(attribute_values(id, value, attributes(id, name)))').inFilter('product_id', productIds).eq('is_active', true).order('sku');
      final raw = List<Map<String, dynamic>>.from(response);
      final map = <String, List<ProductVariantModel>>{};
      for (final row in raw) {
        final pid = row['product_id'] as String;
        final v = ProductVariantModel.fromJson(row);
        map.putIfAbsent(pid, () => []).add(v);
      }
      return right(map);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> fetchVariantStockByVariantIds(List<String> variantIds) async {
    try {
      if (variantIds.isEmpty) return right({});
      final response = await _supabase.from('product_stock_summary').select('variant_id, total_stock').inFilter('variant_id', variantIds);
      final map = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final vid = row['variant_id'] as String?;
        final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
        if (vid != null) map[vid] = stock;
      }
      return right(map);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    return right(null);
  }
}
