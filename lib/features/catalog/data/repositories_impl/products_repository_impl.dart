import 'dart:typed_data';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/data/cache/catalog_lru_cache.dart';
import 'package:inventory_store_app/features/catalog/data/datasources/products_catalog_remote_datasource.dart';
import 'package:inventory_store_app/features/catalog/data/datasources/product_attributes_remote_datasource.dart';
import 'package:inventory_store_app/features/catalog/data/datasources/product_stock_remote_datasource.dart';
import 'package:inventory_store_app/features/catalog/data/datasources/product_media_remote_datasource.dart';
import 'package:inventory_store_app/features/catalog/data/datasources/product_bulk_import_remote_datasource.dart';
import 'package:inventory_store_app/features/catalog/data/datasources/product_reviews_remote_datasource.dart';

@LazySingleton(as: ProductsRepository)
class ProductsRepositoryImpl implements ProductsRepository {
  final SupabaseClient _supabase;
  late final ProductsCatalogRemoteDataSource _catalogDataSource;
  late final ProductAttributesRemoteDataSource _attributesDataSource;
  late final ProductStockRemoteDataSource _stockDataSource;
  late final ProductMediaRemoteDataSource _mediaDataSource;
  late final ProductBulkImportRemoteDataSource _bulkImportDataSource;
  late final ProductReviewsRemoteDataSource _reviewsDataSource;

  // L1 In-Memory Cache para variantes activas y lotes (5 min TTL)
  final Map<String, ({List<Map<String, dynamic>> data, DateTime timestamp})>
  _activeVariantsCache = {};
  final Map<String, ({List<Map<String, dynamic>> data, DateTime timestamp})>
  _batchesForVariantCache = {};
  static const Duration _variantsBatchesCacheTtl = Duration(minutes: 5);

  ProductsRepositoryImpl(this._supabase) {
    _catalogDataSource = ProductsCatalogRemoteDataSource(_supabase);
    _attributesDataSource = ProductAttributesRemoteDataSource(_supabase);
    _stockDataSource = ProductStockRemoteDataSource(_supabase);
    _mediaDataSource = ProductMediaRemoteDataSource(_supabase);
    _bulkImportDataSource = ProductBulkImportRemoteDataSource(_supabase);
    _reviewsDataSource = ProductReviewsRemoteDataSource(_supabase);
  }

  Either<Failure, T> _handleError<T>(Object e, [StackTrace? st]) {
    LoggerService.e(
      'Error en ProductsRepositoryImpl',
      tag: 'PRODUCTS_REPO',
      error: e,
      stackTrace: st,
    );
    if (e is PostgrestException) {
      if (e.code == '23503') {
        return left(
          const ServerFailure(
            message:
                'No se puede eliminar: Este registro o sus valores están siendo utilizados por otros elementos (productos, variantes o inventario) en el sistema.',
            code: '23503',
          ),
        );
      }
      return left(
        ServerFailure(
          message: FriendlyErrorMessage.format(e),
          code: e.code ?? 'POSTGREST_ERROR',
        ),
      );
    } else if (e is StorageException) {
      return left(
        ServerFailure(
          message: 'Error en almacenamiento de imágenes: ${e.message}',
          code: e.statusCode?.toString() ?? 'STORAGE_ERROR',
        ),
      );
    } else if (e is AuthException) {
      return left(
        ServerFailure(
          message: 'Error de autenticación: ${e.message}',
          code: e.statusCode?.toString() ?? 'AUTH_ERROR',
        ),
      );
    }
    return left(Failure.from(e));
  }

  // ───────────────────────── Reseñas y Compras ─────────────────────────

  @override
  Future<Either<Failure, bool>> checkCustomerPurchase(
    String productId,
    String profileId,
  ) async {
    try {
      final purchased = await _reviewsDataSource.checkCustomerPurchase(
        productId,
        profileId,
      );
      return right(purchased);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> addProductReview({
    required String productId,
    required String profileId,
    required String userName,
    required int rating,
    String? comment,
  }) async {
    try {
      await _reviewsDataSource.addProductReview(
        productId: productId,
        profileId: profileId,
        userName: userName,
        rating: rating,
        comment: comment,
      );
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  // ───────────────────────── Catálogo y Productos ─────────────────────────

  @override
  Future<Either<Failure, ({List<ProductEntity> products, int totalCount})>>
  getProducts({
    String? searchQuery,
    String? categoryId,
    String? brandId,
    bool? isActive,
    bool searchByIngredient = false,
    bool forCustomer = false,
    int limit = 20,
    int offset = 0,
    bool sortByPriceAsc = true,
    CatalogStockFilter? stockFilter,
    CatalogSortOption? sortOption,
  }) async {
    try {
      final res = await _catalogDataSource.getProducts(
        searchQuery: searchQuery,
        categoryId: categoryId,
        brandId: brandId,
        isActive: isActive,
        searchByIngredient: searchByIngredient,
        forCustomer: forCustomer,
        limit: limit,
        offset: offset,
        sortByPriceAsc: sortByPriceAsc,
        stockFilter: stockFilter,
        sortOption: sortOption,
      );

      final cacheKey = CatalogLruCache.buildKey(
        searchQuery: searchQuery,
        categoryId: categoryId,
        brandId: brandId,
        isActive: isActive,
        searchByIngredient: searchByIngredient,
        forCustomer: forCustomer,
        limit: limit,
        offset: offset,
        sortOption: sortOption,
        stockFilter: stockFilter,
      );
      CatalogLruCache.instance.putPage(cacheKey, res.products, res.totalCount);

      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  ({List<ProductEntity> products, int totalCount})? getCachedProducts({
    String? searchQuery,
    String? categoryId,
    String? brandId,
    bool? isActive,
    bool searchByIngredient = false,
    bool forCustomer = false,
    int limit = 20,
    int offset = 0,
    CatalogStockFilter? stockFilter,
    CatalogSortOption? sortOption,
  }) {
    final key = CatalogLruCache.buildKey(
      searchQuery: searchQuery,
      categoryId: categoryId,
      brandId: brandId,
      isActive: isActive,
      searchByIngredient: searchByIngredient,
      forCustomer: forCustomer,
      limit: limit,
      offset: offset,
      sortOption: sortOption,
      stockFilter: stockFilter,
    );
    return CatalogLruCache.instance.getPage(key);
  }

  @override
  ProductEntity? getCachedProductById(String id) {
    return CatalogLruCache.instance.getProduct(id);
  }

  @override
  List<Map<String, dynamic>>? getCachedActiveVariants(String productId) {
    final entry = _activeVariantsCache[productId];
    if (entry != null &&
        DateTime.now().difference(entry.timestamp) < _variantsBatchesCacheTtl) {
      return entry.data;
    }
    return null;
  }

  @override
  List<Map<String, dynamic>>? getCachedBatchesForVariant(
    String variantId,
    String warehouseId,
  ) {
    final key = '$variantId:$warehouseId';
    final entry = _batchesForVariantCache[key];
    if (entry != null &&
        DateTime.now().difference(entry.timestamp) < _variantsBatchesCacheTtl) {
      return entry.data;
    }
    return null;
  }

  @override
  Future<Either<Failure, ProductEntity?>> getProductById(
    String id, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = getCachedProductById(id);
      if (cached != null) return right(cached);
    }
    try {
      final entity = await _catalogDataSource.getProductById(id);
      if (entity == null) {
        CatalogLruCache.instance.invalidateProduct(id);
        return right(null);
      }
      CatalogLruCache.instance.putProduct(id, entity);
      return right(entity);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getProductStock({
    List<String>? productIds,
  }) async {
    try {
      final map = await _stockDataSource.getProductStock(
        productIds: productIds,
      );
      return right(map);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> setProductActive({
    required String productId,
    required bool isActive,
  }) async {
    try {
      await _catalogDataSource.setProductActive(productId, isActive);
      CatalogLruCache.instance.invalidateProduct(productId);
      CatalogLruCache.instance.invalidateCatalog();
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, ProductVariantEntity?>> getVariantById(
    String variantId,
  ) async {
    try {
      final variant = await _catalogDataSource.getVariantById(variantId);
      return right(variant);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getStockByVariant(
    String productId,
  ) async {
    try {
      final map = await _stockDataSource.getStockByVariant(productId);
      return right(map);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<VariantDraftEntity>>> getVariantsDrafts(
    String productId,
  ) async {
    try {
      final drafts = await _catalogDataSource.getVariantsDrafts(productId);
      return right(drafts);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>>
  getActiveProductsAndVariants() async {
    try {
      final res = await _catalogDataSource.getActiveProductsAndVariants();
      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  // ───────────────────────── Atributos ─────────────────────────

  @override
  Future<Either<Failure, AttributeEntity>> createAttribute(
    String name, {
    String? description,
  }) async {
    try {
      final attr = await _attributesDataSource.createAttribute(
        name,
        description: description,
      );
      return right(attr);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> updateAttribute(
    String id,
    String name, {
    String? description,
  }) async {
    try {
      await _attributesDataSource.updateAttribute(
        id,
        name,
        description: description,
      );
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteAttribute(String id) async {
    try {
      final hasAssigned = await _attributesDataSource
          .hasAttributeValuesAssigned(id);
      if (hasAssigned) {
        return left(
          const ServerFailure(
            message:
                'No se puede eliminar: Esta propiedad o algunos de sus valores están asignados a variantes de productos existentes en el sistema.',
            code: '23503',
          ),
        );
      }
      await _attributesDataSource.deleteAttribute(id);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, AttributeValueEntity>> createAttributeValue(
    String attributeId,
    String value,
  ) async {
    try {
      final val = await _attributesDataSource.createAttributeValue(
        attributeId,
        value,
      );
      return right(val);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> updateAttributeValue(
    String valueId,
    String value,
  ) async {
    try {
      await _attributesDataSource.updateAttributeValue(valueId, value);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteAttributeValue(String valueId) async {
    try {
      final usageCheck = await _supabase
          .from('variant_attribute_values')
          .select('variant_id')
          .eq('attribute_value_id', valueId)
          .limit(1);

      if ((usageCheck as List).isNotEmpty) {
        return left(
          const ServerFailure(
            message:
                'No se puede eliminar: Este valor está siendo utilizado en una o más variantes de productos existentes.',
            code: '23503',
          ),
        );
      }
      await _attributesDataSource.deleteAttributeValue(valueId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<AttributeEntity>>> getAttributes() async {
    try {
      final list = await _attributesDataSource.getAttributes();
      return right(list);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchAttributes(
    String term,
  ) async {
    try {
      final res = await _attributesDataSource.searchAttributes(term);
      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchAttributeValues(
    String attributeId,
    String term,
  ) async {
    try {
      final res = await _attributesDataSource.searchAttributeValues(
        attributeId,
        term,
      );
      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getOrCreateAttribute(
    String name,
  ) async {
    try {
      final res = await _attributesDataSource.getOrCreateAttribute(name);
      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getOrCreateAttributeValue(
    String attributeId,
    String value,
  ) async {
    try {
      final res = await _attributesDataSource.getOrCreateAttributeValue(
        attributeId,
        value,
      );
      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  // ───────────────────────── Entradas y Lotes ─────────────────────────

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchProductsForEntry(
    String term,
  ) async {
    try {
      final res = await _catalogDataSource.searchProductsForEntry(term);
      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    try {
      final list = await _stockDataSource.getBatchesForVariant(
        variantId,
        warehouseId,
      );
      _batchesForVariantCache['$variantId:$warehouseId'] = (
        data: list,
        timestamp: DateTime.now(),
      );
      return right(list);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  // ───────────────────────── Imágenes y Variantes ─────────────────────────

  @override
  Future<Either<Failure, List<ProductImageEntity>>> getProductImages(
    String productId,
  ) async {
    try {
      final list = await _mediaDataSource.getProductImages(productId);
      return right(list);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, String?>> uploadImageToStorage(
    Uint8List bytes,
    String folder,
  ) async {
    try {
      final url = await _mediaDataSource.uploadImageToStorage(bytes, folder);
      return right(url);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteProductImage(
    String id,
    String imageUrl,
  ) async {
    try {
      await _mediaDataSource.deleteProductImage(id, imageUrl);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> syncProductImages(
    List<Map<String, dynamic>> payload,
  ) async {
    try {
      await _mediaDataSource.syncProductImages(payload);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteVariant(String variantId) async {
    try {
      await _catalogDataSource.deleteVariant(variantId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deactivateVariant(String variantId) async {
    try {
      await _catalogDataSource.deactivateVariant(variantId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> clearVariantImages(String variantId) async {
    try {
      await _supabase
          .from('product_images')
          .update({'variant_id': null})
          .eq('variant_id', variantId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, String>> saveProductMaster(
    ProductEntity product,
    String? profileId,
  ) async {
    try {
      final isUpdating = product.id.isNotEmpty;
      final dataToSave = {
        'name': product.name,
        'is_active': product.isActive,
        'description': product.description,
        'category_id': product.categoryId,
        'brand_id': product.brandId,
        'details': product.details,
        'product_type': product.productType,
        'stock_control': product.stockControl,
        'uses_batches': product.usesBatches,
        if (isUpdating && profileId != null) 'updated_by': profileId,
        if (!isUpdating && profileId != null) 'created_by': profileId,
      };

      if (isUpdating) {
        await _supabase
            .from('products')
            .update(dataToSave)
            .eq('id', product.id);
        CatalogLruCache.instance.invalidateProduct(product.id);
        CatalogLruCache.instance.invalidateCatalog();
        return right(product.id);
      } else {
        final res =
            await _supabase
                .from('products')
                .insert(dataToSave)
                .select('id')
                .single();
        CatalogLruCache.instance.invalidateCatalog();
        return right(res['id'] as String);
      }
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, String>> saveVariant({
    required String productId,
    required Map<String, dynamic> variantData,
    String? variantId,
    String? profileId,
  }) async {
    try {
      final payload = {
        ...variantData,
        'product_id': productId,
        if (variantId != null && profileId != null) 'updated_by': profileId,
        if (variantId == null && profileId != null) 'created_by': profileId,
      };
      if (variantId != null) {
        await _supabase
            .from('product_variants')
            .update(payload)
            .eq('id', variantId);
        return right(variantId);
      } else {
        final res =
            await _supabase
                .from('product_variants')
                .insert(payload)
                .select('id')
                .single();
        return right(res['id'] as String);
      }
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> saveVariantAttributes(
    String variantId,
    List<String> attributeValueIds,
  ) async {
    try {
      await _supabase.rpc(
        'save_variant_attributes_rpc',
        params: {
          'p_variant_id': variantId,
          'p_attribute_value_ids': attributeValueIds,
        },
      );
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, String?>> getFirstVariantId(String productId) async {
    try {
      final vResp =
          await _supabase
              .from('product_variants')
              .select('id')
              .eq('product_id', productId)
              .limit(1)
              .maybeSingle();
      return right(vResp?['id'] as String?);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, bool>> toggleWishlist(
    String productId,
    String profileId,
    bool currentState,
  ) async {
    try {
      if (currentState) {
        await _supabase
            .from('wishlist')
            .delete()
            .eq('profile_id', profileId)
            .eq('product_id', productId);
        return right(false);
      } else {
        final existing =
            await _supabase
                .from('wishlist')
                .select('id')
                .eq('profile_id', profileId)
                .eq('product_id', productId)
                .maybeSingle();
        if (existing != null) {
          await _supabase
              .from('wishlist')
              .delete()
              .eq('profile_id', profileId)
              .eq('product_id', productId);
          return right(false);
        }
        await _supabase.from('wishlist').insert({
          'profile_id': profileId,
          'product_id': productId,
        });
        return right(true);
      }
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchAdminFinancialData(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('order_items')
          .select(
            'quantity, unit_cost, applied_price, variant_id, orders!inner(status)',
          )
          .eq('product_id', productId)
          .eq('orders.status', 'COMPLETED')
          .limit(500);
      return right(List<Map<String, dynamic>>.from(response as List));
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<
    Either<
      Failure,
      ({
        List<Map<String, dynamic>> stocks,
        List<Map<String, dynamic>> batches,
        List<ProductImageEntity> images,
        List<ProductVariantEntity> variants,
        List<Map<String, dynamic>> reviews,
        List<Map<String, dynamic>> ingredients,
      })
    >
  >
  fetchProductExtraData(String productId) async {
    try {
      final queries = <Future<dynamic>>[
        _supabase
            .from('warehouse_stock_batches')
            .select(
              'id, available_quantity, variant_id, warehouse_id, batch_number, expiry_date, warehouses(name)',
            )
            .eq('product_id', productId)
            .order('expiry_date', ascending: true, nullsFirst: false),
        _supabase
            .from('product_images')
            .select(
              'id, product_id, variant_id, image_url, display_order, is_main',
            )
            .eq('product_id', productId)
            .order('display_order', ascending: true),
        _supabase
            .from('product_variants')
            .select(
              'id, product_id, sku, variant_attribute_values(attribute_values(id, value, attributes(name))), product_images(id, image_url, variant_id), sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, unit_cost',
            )
            .eq('product_id', productId)
            .eq('is_active', true)
            .order('created_at', ascending: true),
        _supabase
            .from('product_reviews')
            .select('rating, comment, user_name, created_at')
            .eq('product_id', productId)
            .order('created_at', ascending: false)
            .limit(50),
        _supabase
            .from('product_active_ingredients')
            .select(
              'concentration, unit, active_ingredients(id, name, description)',
            )
            .eq('product_id', productId),
      ];

      final results = await Future.wait(queries);

      final rawStocks = results[0] as List<dynamic>;
      final aggregatedStocks = <String, Map<String, dynamic>>{};
      final validBatches = <Map<String, dynamic>>[];

      for (final row in rawStocks) {
        final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
        validBatches.add(Map<String, dynamic>.from(row as Map));
        final wId = row['warehouse_id']?.toString() ?? 'unknown';
        final vId = row['variant_id']?.toString() ?? 'none';
        final key = '${wId}_$vId';
        if (aggregatedStocks.containsKey(key)) {
          aggregatedStocks[key]!['available_quantity'] =
              (aggregatedStocks[key]!['available_quantity'] as int) + stock;
        } else {
          aggregatedStocks[key] = {
            'warehouse_id': row['warehouse_id'],
            'variant_id': row['variant_id'],
            'warehouses': row['warehouses'],
            'available_quantity': stock,
          };
        }
      }

      return right((
        stocks: aggregatedStocks.values.toList(),
        batches: validBatches,
        images:
            (results[1] as List)
                .map(
                  (e) =>
                      ProductImageModel.fromJson(
                        Map<String, dynamic>.from(e),
                      ).toEntity(),
                )
                .toList(),
        variants:
            (results[2] as List)
                .map(
                  (e) =>
                      ProductVariantModel.fromJson(
                        Map<String, dynamic>.from(e),
                      ).toEntity(),
                )
                .toList(),
        reviews: List<Map<String, dynamic>>.from(results[3] as List),
        ingredients: List<Map<String, dynamic>>.from(results[4] as List),
      ));
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> loadStockByVariant(
    String productId, {
    String? warehouseId,
  }) async {
    try {
      if (warehouseId != null && warehouseId.isNotEmpty) {
        final varRes = await _supabase
            .from('product_variants')
            .select('id')
            .eq('product_id', productId);
        final vIds =
            List<Map<String, dynamic>>.from(
              varRes,
            ).map((r) => r['id'] as String).toList();
        return await fetchVariantStockByVariantIds(
          vIds,
          warehouseId: warehouseId,
        );
      }
      final response = await _supabase
          .from('product_stock_summary')
          .select('variant_id, total_stock')
          .eq('product_id', productId);
      final map = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(response)) {
        final vid = row['variant_id'] as String?;
        final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
        if (vid != null) map[vid] = stock;
      }
      return right(map);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> loadActiveVariants(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product_variants')
          .select(
            'id, product_id, sku, sale_price, wholesale_price, wholesale_min_quantity, is_active, unit_cost, product_images(id, product_id, variant_id, image_url, is_main, display_order), variant_attribute_values(attribute_values(id, value, attributes(id, name)))',
          )
          .eq('product_id', productId)
          .eq('is_active', true)
          .order('sku');
      final list = List<Map<String, dynamic>>.from(response);
      _activeVariantsCache[productId] = (data: list, timestamp: DateTime.now());
      return right(list);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, List<ProductVariantEntity>>>>
  fetchVariantsByProductIds(List<String> productIds) async {
    try {
      if (productIds.isEmpty) return right({});
      final response = await _supabase
          .from('product_variants')
          .select(
            '*, product_images(id, image_url, is_main, display_order), variant_attribute_values(attribute_values(id, value, attributes(id, name)))',
          )
          .inFilter('product_id', productIds)
          .eq('is_active', true)
          .order('sku');
      final raw = List<Map<String, dynamic>>.from(response);
      final map = <String, List<ProductVariantEntity>>{};
      for (final row in raw) {
        final pid = row['product_id'] as String;
        map
            .putIfAbsent(pid, () => [])
            .add(ProductVariantModel.fromJson(row).toEntity());
      }
      return right(map);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> fetchVariantStockByVariantIds(
    List<String> variantIds, {
    String? warehouseId,
  }) async {
    try {
      if (variantIds.isEmpty) return right({});
      if (warehouseId != null && warehouseId.isNotEmpty) {
        final response = await _supabase
            .from('warehouse_stock_batches')
            .select('variant_id, available_quantity')
            .inFilter('variant_id', variantIds)
            .eq('warehouse_id', warehouseId);

        final map = <String, int>{};
        for (final row in List<Map<String, dynamic>>.from(response)) {
          final vid = row['variant_id'] as String?;
          final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
          if (vid != null) {
            map[vid] = (map[vid] ?? 0) + stock;
          }
        }
        return right(map);
      } else {
        final response = await _supabase
            .from('product_stock_summary')
            .select('variant_id, total_stock')
            .inFilter('variant_id', variantIds);

        final map = <String, int>{};
        for (final row in List<Map<String, dynamic>>.from(response)) {
          final vid = row['variant_id'] as String?;
          final stock = (row['total_stock'] as num?)?.toInt() ?? 0;
          if (vid != null) map[vid] = stock;
        }
        return right(map);
      }
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, bool>> checkWishlistState(
    String productId,
    String profileId,
  ) async {
    try {
      final res =
          await _supabase
              .from('wishlist')
              .select('id')
              .eq('profile_id', profileId)
              .eq('product_id', productId)
              .maybeSingle();
      return right(res != null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    _activeVariantsCache.clear();
    _batchesForVariantCache.clear();
    CatalogLruCache.instance.clear();
    return right(null);
  }

  // ───────────────────────── Guardado Completo ─────────────────────────

  @override
  Future<Either<Failure, void>> saveProductComplete(
    SaveProductPayload payload,
  ) async {
    final List<String> uploadedPaths = [];
    try {
      final imageUploadFutures =
          payload.images.asMap().entries.map((entry) async {
            final i = entry.key;
            final item = entry.value;
            final isMain = (i == 0);

            if (item.existingId != null) {
              return {
                'id': item.existingId,
                'image_url': item.existingUrl,
                'display_order': i,
                'is_main': isMain,
              };
            } else if (item.externalImageUrl != null &&
                item.externalImageUrl!.trim().isNotEmpty) {
              return {
                'image_url': item.externalImageUrl!.trim(),
                'display_order': i,
                'is_main': isMain,
              };
            } else if (item.newBytes != null) {
              final fileName =
                  '${DateTime.now().millisecondsSinceEpoch}_p$i.jpg';
              final path = 'productos/$fileName';
              await _supabase.storage
                  .from('products')
                  .uploadBinary(
                    path,
                    item.newBytes!,
                    fileOptions: const FileOptions(
                      contentType: 'image/jpeg',
                      upsert: false,
                    ),
                  );
              uploadedPaths.add(path);
              final publicUrl = _supabase.storage
                  .from('products')
                  .getPublicUrl(path);
              return {
                'image_url': publicUrl,
                'display_order': i,
                'is_main': isMain,
              };
            }
            return null;
          }).toList();

      final variantFutures =
          payload.variants.asMap().entries.map((entry) async {
            final i = entry.key;
            final draft = entry.value;
            String? newImageUrl;
            if (draft.newImageBytes != null) {
              final fileName =
                  '${DateTime.now().millisecondsSinceEpoch}_v$i.jpg';
              final path = 'variantes/$fileName';
              await _supabase.storage
                  .from('products')
                  .uploadBinary(
                    path,
                    draft.newImageBytes!,
                    fileOptions: const FileOptions(
                      contentType: 'image/jpeg',
                      upsert: false,
                    ),
                  );
              uploadedPaths.add(path);
              newImageUrl = _supabase.storage
                  .from('products')
                  .getPublicUrl(path);
            }

            final effectiveImageUrl = newImageUrl ?? draft.externalImageUrl;

            return {
              'id': draft.id,
              'sku': draft.sku,
              'barcode': draft.barcode,
              'unit_cost': draft.unitCost,
              'sale_price': draft.salePrice,
              'wholesale_price': draft.wholesalePrice,
              'wholesale_min_quantity': draft.wholesaleMinQuantity,
              'reorder_point': draft.reorderPoint,
              'is_active': draft.isActive,
              'attribute_value_ids': draft.attributeValueIds,
              'clear_images': draft.clearImages,
              if (effectiveImageUrl != null) 'image_url': effectiveImageUrl,
            };
          }).toList();

      final productImagesJson =
          (await Future.wait(
            imageUploadFutures,
          )).whereType<Map<String, dynamic>>().toList();
      final variantsJson = await Future.wait(variantFutures);

      final ingredientsJson =
          payload.ingredientsEnabled
              ? payload.ingredients
                  .map(
                    (ing) => {
                      'ingredient_id': ing.ingredientId,
                      'concentration': ing.concentration,
                      'unit': ing.unit,
                    },
                  )
                  .toList()
              : [];

      var effectiveProfileId = payload.profileId;
      if (effectiveProfileId == null || effectiveProfileId.trim().isEmpty) {
        final authUserId = _supabase.auth.currentUser?.id;
        if (authUserId != null) {
          try {
            final pRes =
                await _supabase
                    .from('profiles')
                    .select('id')
                    .eq('auth_user_id', authUserId)
                    .maybeSingle();
            effectiveProfileId = pRes?['id'] as String?;
          } catch (e) {
            LoggerService.w(
              'No se pudo resolver profile_id en saveProductComplete: $e',
              tag: 'PRODUCTS_REPO',
            );
          }
        }
      }

      final jsonPayload = {
        'is_updating': payload.isUpdating,
        'profile_id': effectiveProfileId,
        'product': {
          'id': payload.product.id,
          'name': payload.product.name,
          'description': payload.product.description,
          'category_id': payload.product.categoryId,
          'brand_id': payload.product.brandId,
          'is_active': payload.product.isActive,
          'details': payload.product.details,
          'product_type': payload.product.productType,
          'stock_control': payload.product.stockControl,
          'uses_batches': payload.product.usesBatches,
        },
        'removed_variant_ids': payload.removedVariantIds,
        'images': productImagesJson,
        'variants': variantsJson,
        'ingredients_enabled': payload.ingredientsEnabled,
        'ingredients': ingredientsJson,
      };

      await _catalogDataSource.saveProductComplete(jsonPayload);
      if (payload.product.id.isNotEmpty) {
        CatalogLruCache.instance.invalidateProduct(payload.product.id);
      }
      CatalogLruCache.instance.invalidateCatalog();
      return right(null);
    } catch (e, st) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _supabase.storage.from('products').remove(uploadedPaths);
        } catch (err) {
          LoggerService.e('Rollback failed for images: $err');
        }
      }
      return _handleError(e, st);
    }
  }

  // ───────────────────────── Importación Masiva ─────────────────────────

  @override
  Future<Either<Failure, ImportCatalogContext>>
  getImportCatalogContext() async {
    try {
      final ctx = await _bulkImportDataSource.getImportCatalogContext();
      return right(ctx);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<ExistingVariant>>> findExistingVariants({
    required List<String> productNames,
    required List<String> skus,
    required String? warehouseId,
  }) async {
    try {
      final list = await _bulkImportDataSource.findExistingVariants(
        productNames: productNames,
        skus: skus,
        warehouseId: warehouseId,
      );
      return right(list);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, ImportBatchResult>> importCatalogBatch({
    required List<Map<String, dynamic>> products,
    required String? warehouseId,
    required String stockMode,
    required bool updatePrices,
    required String batchId,
  }) async {
    try {
      final res = await _bulkImportDataSource.importCatalogBatch(
        products: products,
        warehouseId: warehouseId,
        stockMode: stockMode,
        updatePrices: updatePrices,
        batchId: batchId,
      );
      CatalogLruCache.instance.clear();
      return right(res);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, bool>> hasVariantSales(String variantId) async {
    try {
      final rows = await _supabase
          .from('order_items')
          .select('id')
          .eq('variant_id', variantId)
          .limit(1);
      return right((rows as List).isNotEmpty);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      final imageUrls = await _catalogDataSource.deleteProductSafely(id);
      CatalogLruCache.instance.invalidateProduct(id);
      CatalogLruCache.instance.invalidateCatalog();

      if (imageUrls.isNotEmpty) {
        try {
          await _mediaDataSource.deleteImagesFromUrls(imageUrls);
        } catch (e, st) {
          LoggerService.e(
            'Error al borrar imágenes del bucket',
            tag: 'PRODUCTS_REPO',
            error: e,
            stackTrace: st,
          );
        }
      }

      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }
}
