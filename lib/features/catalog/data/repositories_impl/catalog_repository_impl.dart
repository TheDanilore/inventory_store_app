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
  Future<Either<Failure, void>> clearCache() async {
    // Implement cache clearing if needed
    return right(null);
  }
}
