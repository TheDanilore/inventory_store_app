import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/utils/isolate_utils.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@LazySingleton(as: ProductsRepository)
class ProductsRepositoryImpl implements ProductsRepository {
  final SupabaseClient _supabase;

  ProductsRepositoryImpl(this._supabase);

  Either<Failure, T> _handleError<T>(Object e, [StackTrace? st]) {
    LoggerService.e('Error en ProductsRepositoryImpl', tag: 'PRODUCTS_REPO', error: e, stackTrace: st);
    if (e is PostgrestException) {
      if (e.code == '23503') {
        return left(
          Failure.from(
            'No se puede eliminar: Este registro o sus valores están siendo utilizados por otros elementos (productos, variantes o inventario) en el sistema.',
          ),
        );
      }
      return left(Failure.from('Error de BD: ${e.message}'));
    } else if (e is StorageException) {
      return left(Failure.from('Error en Storage (Imágenes): ${e.message}'));
    } else if (e is AuthException) {
      return left(Failure.from('Error de autenticación: ${e.message}'));
    }
    return left(Failure.from('Ocurrió un error inesperado: ${e.toString()}'));
  }

  @override
  Future<Either<Failure, bool>> checkCustomerPurchase(
    String productId,
    String profileId,
  ) async {
    try {
      final purchases = await _supabase
          .from('order_items')
          .select('id, orders!inner(customer_id)')
          .eq('product_id', productId)
          .eq('orders.customer_id', profileId)
          .limit(1);
      return right(purchases.isNotEmpty);
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
      await _supabase.from('product_reviews').insert({
        'product_id': productId,
        'profile_id': profileId,
        'user_name': userName,
        'rating': rating,
        'comment': comment,
      });
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  // Mutaciones complejas
  @override
  Future<Either<Failure, ({List<ProductEntity> products, int totalCount})>>
  getProducts({
    String? searchQuery,
    String? categoryId,
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
      String variantSelect =
          forCustomer
              ? 'product_variants(id, product_id, sku, sale_price, is_active, product_images(*))'
              : 'product_variants(id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, product_images(*))';
      String selectString =
          'id, name, is_active, description, category_id, details, created_at, updated_at, stock_control, uses_batches, product_type, product_images(id, product_id, image_url, is_main, display_order), categories(name), warehouse_stock_batches(id, product_id, variant_id, available_quantity), $variantSelect';

      if (searchByIngredient &&
          searchQuery != null &&
          searchQuery.trim().isNotEmpty) {
        selectString +=
            ', product_active_ingredients!inner(active_ingredients!inner(name))';
      } else {
        selectString +=
            ', product_active_ingredients(active_ingredients(name))';
      }

      var query = _supabase.from('products').select(selectString);

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.eq('category_id', categoryId);
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        if (searchByIngredient) {
          query = query.ilike(
            'product_active_ingredients.active_ingredients.name',
            '%${searchQuery.trim()}%',
          );
        } else {
          query = query.ilike('name', '%${searchQuery.trim()}%');
        }
      }

      if (stockFilter != null && stockFilter != CatalogStockFilter.all) {
        var stockQuery = _supabase
            .from('product_stock_summary')
            .select('product_id');

        if (stockFilter == CatalogStockFilter.inStock) {
          stockQuery = stockQuery.gt('total_stock', 0);
        } else if (stockFilter == CatalogStockFilter.outOfStock) {
          stockQuery = stockQuery.eq('total_stock', 0);
        }

        final summaryRes = await stockQuery;
        final matchingIds = <String>{};
        for (final row in List<Map<String, dynamic>>.from(summaryRes)) {
          final pid = row['product_id'] as String?;
          if (pid != null) {
            matchingIds.add(pid);
          }
        }
        if (matchingIds.isEmpty) {
          return right((products: <ProductEntity>[], totalCount: 0));
        }
        query = query.inFilter('id', matchingIds.toList());
      }

      var transformQuery = query.order('is_active', ascending: false); // Productos activos primero

      transformQuery = sortOption == CatalogSortOption.recent
          ? transformQuery.order('created_at', ascending: false)
          : transformQuery.order('name', ascending: true);
      transformQuery = transformQuery.range(offset, offset + limit - 1);
      final response = await transformQuery.count(CountOption.exact);

      final responseData = response.data as List;
      var entities = await IsolateUtils.run(() {
        final models =
            List<Map<String, dynamic>>.from(
              responseData,
            ).map(ProductModel.fromJson).toList();
        return models.map((m) => m.toEntity()).toList();
      });

      if (sortOption == CatalogSortOption.priceAsc) {
        entities.sort(
          (a, b) =>
              (a.displaySalePrice ?? 0).compareTo(b.displaySalePrice ?? 0),
        );
      } else if (sortOption == CatalogSortOption.priceDesc) {
        entities.sort(
          (a, b) =>
              (b.displaySalePrice ?? 0).compareTo(a.displaySalePrice ?? 0),
        );
      } else if (sortOption == CatalogSortOption.highStock) {
        entities.sort((a, b) => b.totalStock.compareTo(a.totalStock));
      }

      return right((products: entities, totalCount: response.count));
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, ProductEntity?>> getProductById(String id) async {
    try {
      final response =
          await _supabase
              .from('products')
              .select(
                'id, name, is_active, description, category_id, details, created_at, updated_at, stock_control, uses_batches, product_type, product_images(*), categories(name), product_variants(id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))), warehouse_stock_batches(*)',
              )
              .eq('id', id)
              .maybeSingle();

      if (response == null) return right(null);
      final model = ProductModel.fromJson(response);
      return right(model.toEntity());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getProductStock({
    List<String>? productIds,
  }) async {
    try {
      var query = _supabase
          .from('warehouse_stock_batches')
          .select('product_id, available_quantity');
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
      await _supabase
          .from('products')
          .update({'is_active': isActive})
          .eq('id', productId);
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
      final response =
          await _supabase
              .from('product_variants')
              .select(
                'id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))',
              )
              .eq('id', variantId)
              .maybeSingle();

      if (response == null) return right(null);
      final model = ProductVariantModel.fromJson(response);
      return right(model.toEntity());
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getStockByVariant(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('warehouse_stock_batches')
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
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<VariantDraftEntity>>> getVariantsDrafts(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product_variants')
          .select(
            'id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))',
          )
          .eq('product_id', productId)
          .eq('is_active', true)
          .order('created_at');

      final drafts =
          List<Map<String, dynamic>>.from(response).map((json) {
            final variant = ProductVariantModel.fromJson(json);
            return VariantDraftEntity.fromVariant(variant.toEntity());
          }).toList();
      return right(drafts);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>>
  getActiveProductsAndVariants() async {
    try {
      final response = await _supabase
          .from('products')
          .select(
            'id, name, is_active, product_variants(id, product_id, sku, sale_price, is_active)',
          )
          .eq('is_active', true)
          .eq('product_variants.is_active', true);

      final products = <Map<String, dynamic>>[];
      final variants = <Map<String, dynamic>>[];

      for (var product in response) {
        final pVariants = product['product_variants'] as List<dynamic>? ?? [];
        products.add({
          'id': product['id'],
          'name': product['name'],
          'is_active': product['is_active'],
        });
        variants.addAll(pVariants.map((v) => Map<String, dynamic>.from(v)));
      }

      return right({'products': products, 'variants': variants});
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, AttributeEntity>> createAttribute(
    String name, {
    String? description,
  }) async {
    try {
      final payload = {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      };
      final res =
          await _supabase
              .from('attributes')
              .insert(payload)
              .select('id, name, description')
              .single();
      return right(
        AttributeEntity(
          id: res['id'],
          name: res['name'],
          description: res['description'] as String?,
        ),
      );
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
      final payload = {
        'name': name.trim(),
        'description':
            (description != null && description.trim().isNotEmpty)
                ? description.trim()
                : null,
      };
      await _supabase.from('attributes').update(payload).eq('id', id);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteAttribute(String id) async {
    try {
      final valuesRes = await _supabase
          .from('attribute_values')
          .select('id')
          .eq('attribute_id', id);
      final valueIds =
          (valuesRes as List).map((v) => v['id'] as String).toList();

      if (valueIds.isNotEmpty) {
        final usageCheck = await _supabase
            .from('variant_attribute_values')
            .select('variant_id')
            .inFilter('attribute_value_id', valueIds)
            .limit(1);

        if ((usageCheck as List).isNotEmpty) {
          return left(
            Failure.from(
              'No se puede eliminar: Esta propiedad o algunos de sus valores están asignados a variantes de productos existentes en el sistema.',
            ),
          );
        }
      }

      await _supabase.from('attributes').delete().eq('id', id);
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
      final res =
          await _supabase
              .from('attribute_values')
              .insert({'attribute_id': attributeId, 'value': value.trim()})
              .select('id, attribute_id, value')
              .single();
      return right(
        AttributeValueEntity(
          id: res['id'],
          attributeId: res['attribute_id'],
          value: res['value'],
        ),
      );
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
      await _supabase
          .from('attribute_values')
          .update({'value': value.trim()})
          .eq('id', valueId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  // --- BÚSQUEDA PARA UI (ATRIBUTOS) ---
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchAttributes(
    String term,
  ) async {
    try {
      var query = _supabase.from('attributes').select('id, name');
      if (term.trim().isNotEmpty) {
        query = query.ilike('name', '%${term.trim()}%');
      }
      final res = await query.order('name').limit(15);
      return right(List<Map<String, dynamic>>.from(res));
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
      var query = _supabase
          .from('attribute_values')
          .select('id, value')
          .eq('attribute_id', attributeId);
      if (term.trim().isNotEmpty) {
        query = query.ilike('value', '%${term.trim()}%');
      }
      final res = await query.order('value').limit(15);
      return right(List<Map<String, dynamic>>.from(res));
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getOrCreateAttribute(
    String name,
  ) async {
    try {
      // Uso de un RPC o query atómico sería ideal, pero simulamos un upsert atómico:
      // Supabase no tiene 'ON CONFLICT DO NOTHING RETURNING id' directo en insert simple si no hay un constraint unique definido en 'name',
      // pero asumiendo que 'name' es unique, podemos intentar insertar y si falla buscar,
      // o usar el método seguro de Supabase upsert (onConflict).
      // Para no romper la DB si 'name' no es un constraint real, hacemos el select primero por ahora o preferiblemente upsert.
      final exist =
          await _supabase
              .from('attributes')
              .select('id, name')
              .ilike('name', name.trim())
              .maybeSingle();
      if (exist != null) return right(exist);

      final res =
          await _supabase
              .from('attributes')
              .insert({'name': name.trim()})
              .select('id, name')
              .single();
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
      final exist =
          await _supabase
              .from('attribute_values')
              .select('id, value')
              .eq('attribute_id', attributeId)
              .ilike('value', value.trim())
              .maybeSingle();
      if (exist != null) return right(exist);

      final res =
          await _supabase
              .from('attribute_values')
              .insert({'attribute_id': attributeId, 'value': value.trim()})
              .select('id, value')
              .single();
      return right(res);
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
          Failure.from(
            'No se puede eliminar: Este valor está siendo utilizado en una o más variantes de productos existentes.',
          ),
        );
      }

      await _supabase.from('attribute_values').delete().eq('id', valueId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<AttributeEntity>>> getAttributes() async {
    try {
      final response = await _supabase
          .from('attributes')
          .select(
            'id, name, description, attribute_values(id, attribute_id, value)',
          )
          .order('name');

      final list =
          List<Map<String, dynamic>>.from(response).map((row) {
            final valuesList = (row['attribute_values'] as List?) ?? [];
            return AttributeEntity(
              id: row['id'],
              name: row['name'],
              description: row['description'],
              values:
                  valuesList
                      .map(
                        (v) => AttributeValueEntity(
                          id: v['id'],
                          attributeId: v['attribute_id'] ?? row['id'],
                          value: v['value'],
                        ),
                      )
                      .toList(),
            );
          }).toList();

      return right(list);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<ProductImageEntity>>> getProductImages(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product_images')
          .select('id, product_id, image_url, is_main, display_order')
          .eq('product_id', productId)
          .order('display_order');
      final models =
          List<Map<String, dynamic>>.from(
            response,
          ).map(ProductImageModel.fromJson).toList();
      return right(models.map((m) => m.toEntity()).toList());
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
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$folder/$fileName';
      await _supabase.storage.from('products').uploadBinary(path, bytes);
      final publicUrl = _supabase.storage.from('products').getPublicUrl(path);
      return right(publicUrl);
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
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> syncProductImages(
    List<Map<String, dynamic>> payload,
  ) async {
    try {
      await _supabase.from('product_images').upsert(payload, onConflict: 'id');
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteVariant(String variantId) async {
    try {
      await _supabase.from('product_variants').delete().eq('id', variantId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deactivateVariant(String variantId) async {
    try {
      await _supabase
          .from('product_variants')
          .update({'is_active': false})
          .eq('id', variantId);
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, bool>> hasVariantSales(String variantId) async {
    try {
      final count = await _supabase
          .from('order_items')
          .select()
          .eq('variant_id', variantId)
          .count(CountOption.exact);
      return right(count.count > 0);
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
        return right(product.id);
      } else {
        final res =
            await _supabase
                .from('products')
                .insert(dataToSave)
                .select('id')
                .single();
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
      return right(List<Map<String, dynamic>>.from(response));
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
    // Implementación futura si hay caché local
    return right(null);
  }

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
            } else if (item.newBytes != null) {
              final fileName =
                  '${DateTime.now().millisecondsSinceEpoch}_p$i.jpg';
              final path = 'productos/$fileName';
              await _supabase.storage
                  .from('products')
                  .uploadBinary(path, item.newBytes!);
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
                  .uploadBinary(path, draft.newImageBytes!);
              uploadedPaths.add(path);
              newImageUrl = _supabase.storage
                  .from('products')
                  .getPublicUrl(path);
            } else if (draft.externalImageUrl != null) {
              newImageUrl = draft.externalImageUrl;
            }
            return {
              'id': draft.id,
              'sku': draft.sku,
              'unit_cost': draft.unitCost,
              'sale_price': draft.salePrice ?? payload.baseSalePrice,
              'wholesale_price':
                  draft.wholesalePrice ?? payload.baseWholesalePrice,
              'wholesale_min_quantity':
                  draft.wholesaleMinQuantity ??
                  payload.baseWholesaleMinQuantity,
              'reorder_point': draft.reorderPoint ?? 3,
              'is_active': draft.isActive,
              'clear_images': draft.clearImages,
              'new_image_url': newImageUrl,
              'attribute_value_ids': draft.attributeValueIds,
            };
          }).toList();

      final imagesResults = await Future.wait(imageUploadFutures);
      final variantsResults = await Future.wait(variantFutures);

      final productImagesJson = imagesResults.where((e) => e != null).toList();
      final variantsJson = variantsResults.toList();

      if (variantsJson.isEmpty) {
        variantsJson.add({
          'is_active': true,
          'sale_price': payload.baseSalePrice,
          'wholesale_price': payload.baseWholesalePrice,
          'wholesale_min_quantity': payload.baseWholesaleMinQuantity,
          'unit_cost': 0.0,
          'attribute_value_ids': [],
        });
      }

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

      final jsonPayload = {
        'is_updating': payload.isUpdating,
        'profile_id': payload.profileId,
        'product': {
          'id': payload.product.id,
          'name': payload.product.name,
          'description': payload.product.description,
          'category_id': payload.product.categoryId,
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

      await _supabase.rpc(
        'save_product_complete',
        params: {'payload': jsonPayload},
      );
      return right(null);
    } catch (e, st) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _supabase.storage.from('products').remove(uploadedPaths);
        } catch (err) {
          developer.log('Rollback failed for images', error: err);
        }
      }
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchProductsForEntry(
    String term,
  ) async {
    try {
      final res = await _supabase
          .from('products')
          .select('id, name, uses_batches, product_images!left(image_url)')
          .eq('is_active', true)
          .ilike('name', '%$term%')
          .eq('product_images.is_main', true)
          .limit(20);
      return right(List<Map<String, dynamic>>.from(res));
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
      final response = await _supabase
          .from('warehouse_stock_batches')
          .select('batch_number, expiry_date, available_quantity')
          .eq('variant_id', variantId)
          .eq('warehouse_id', warehouseId)
          .order('expiry_date', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true);
      return right(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      return _handleError(e, st);
    }
  }
  @override
  Future<Either<Failure, void>> importCatalogBatch(
    List<Map<String, dynamic>> payload,
    String? warehouseId,
  ) async {
    try {
      await _supabase.rpc(
        'import_catalog_batch',
        params: {'payload': payload, 'p_warehouse_id': warehouseId},
      );
      return right(null);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, List<String>>> getExistingSkus(List<String> skus) async {
    try {
      if (skus.isEmpty) return right([]);
      final response = await _supabase
          .from('product_variants')
          .select('sku')
          .inFilter('sku', skus);
      
      final existingSkus = List<Map<String, dynamic>>.from(response)
          .map((e) => e['sku'].toString())
          .toList();
      return right(existingSkus);
    } catch (e, st) {
      return _handleError(e, st);
    }
  }

  @override
  Future<Either<Failure, void>> deleteProduct(String id) async {
    try {
      final response = await _supabase.rpc(
        'delete_product_safely',
        params: {'p_product_id': id},
      );

      final imageUrls = (response as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      
      if (imageUrls.isNotEmpty) {
        // Extraer los paths relativos asumiendo que están en el bucket 'products'
        // El image_url podría ser un path relativo o una URL completa, pero usualmente 
        // Supabase storage espera el path (ej. 'folder/file.jpg').
        // Intentaremos borrarlos pero si falla no abortaremos la eliminación en BD.
        try {
          // Extraemos los paths después del nombre del bucket si es URL completa,
          // o lo usamos tal cual si es relativo.
          final paths = imageUrls.map((url) {
            if (url.contains('/storage/v1/object/public/products/')) {
              return url.split('/storage/v1/object/public/products/').last;
            }
            return url;
          }).toList();
          
          await _supabase.storage.from('products').remove(paths);
        } catch (e) {
          developer.log('ProductsRepositoryImpl: Error al borrar imágenes del bucket', error: e);
        }
      }

      return const Right(null);
    } catch (e, st) {
      developer.log('ProductsRepositoryImpl: Error al eliminar producto', error: e, stackTrace: st);
      return _handleError(e, st);
    }
  }
}
