import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/utils/isolate_utils.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

class ProductsCatalogRemoteDataSource {
  final SupabaseClient _supabase;

  ProductsCatalogRemoteDataSource(this._supabase);

  Future<({List<ProductEntity> products, int totalCount})> getProducts({
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
    String variantSelect =
        forCustomer
            ? 'product_variants(id, product_id, sku, sale_price, is_active, variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name))))'
            : 'product_variants(id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name))))';
    final bool isInStockFilter = stockFilter == CatalogStockFilter.inStock;
    const String batchesColumns =
        'id, variant_id, warehouse_id, product_id, batch_number, expiry_date, available_quantity';
    final String batchesJoin =
        isInStockFilter
            ? 'warehouse_stock_batches!inner($batchesColumns)'
            : 'warehouse_stock_batches($batchesColumns)';

    String selectString =
        'id, name, is_active, category_id, brand_id, details, created_at, updated_at, stock_control, uses_batches, product_type, product_images(id, product_id, image_url, is_main, display_order), categories(name), brands(id, name, logo_url), $batchesJoin, $variantSelect';

    if (searchByIngredient &&
        searchQuery != null &&
        searchQuery.trim().isNotEmpty) {
      selectString +=
          ', product_active_ingredients!inner(active_ingredients!inner(name))';
    } else if (searchByIngredient) {
      selectString += ', product_active_ingredients(active_ingredients(name))';
    }

    var query = _supabase.from('products').select(selectString);

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (brandId != null && brandId.isNotEmpty) {
      query = query.eq('brand_id', brandId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final clean = searchQuery.trim();
      if (searchByIngredient) {
        query = query.ilike(
          'product_active_ingredients.active_ingredients.name',
          '%$clean%',
        );
      } else {
        try {
          final variantMatches = await _supabase
              .from('product_variants')
              .select('product_id')
              .or('sku.ilike.%$clean%,barcode.ilike.%$clean%')
              .limit(50);

          final matchingProductIds =
              (variantMatches as List)
                  .map((row) => row['product_id'] as String?)
                  .where((id) => id != null && id.isNotEmpty)
                  .toSet()
                  .toList();

          if (matchingProductIds.isNotEmpty) {
            query = query.or(
              'name.ilike.%$clean%,id.in.(${matchingProductIds.join(',')})',
            );
          } else {
            query = query.ilike('name', '%$clean%');
          }
        } catch (_) {
          query = query.ilike('name', '%$clean%');
        }
      }
    }

    if (isInStockFilter) {
      query = query.gt('warehouse_stock_batches.available_quantity', 0);
    } else if (stockFilter == CatalogStockFilter.outOfStock) {
      final summaryRes = await _supabase
          .from('product_stock_summary')
          .select('product_id, total_stock');

      final stockByProduct = <String, num>{};
      for (final row in List<Map<String, dynamic>>.from(summaryRes)) {
        final pid = row['product_id'] as String?;
        if (pid != null && pid.isNotEmpty) {
          stockByProduct[pid] =
              (stockByProduct[pid] ?? 0) + ((row['total_stock'] as num?) ?? 0);
        }
      }

      final outOfStockIds =
          stockByProduct.entries
              .where((e) => e.value <= 0)
              .map((e) => e.key)
              .toList();

      if (outOfStockIds.isEmpty) {
        return (products: <ProductEntity>[], totalCount: 0);
      }
      query = query.inFilter('id', outOfStockIds);
    }

    var transformQuery = query.order('is_active', ascending: false);

    if (sortOption == CatalogSortOption.recent) {
      transformQuery = transformQuery.order('created_at', ascending: false);
    } else if (sortOption == CatalogSortOption.nameAsc) {
      transformQuery = transformQuery.order('name', ascending: true);
    } else if (sortOption == CatalogSortOption.priceAsc) {
      transformQuery = transformQuery.order(
        'sale_price',
        referencedTable: 'product_variants',
        ascending: true,
      );
    } else if (sortOption == CatalogSortOption.priceDesc) {
      transformQuery = transformQuery.order(
        'sale_price',
        referencedTable: 'product_variants',
        ascending: false,
      );
    } else {
      transformQuery = transformQuery.order('created_at', ascending: false);
    }
    transformQuery = transformQuery.range(offset, offset + limit - 1);
    final response = await transformQuery.count(CountOption.exact);

    final responseData = response.data as List;
    var entities = await IsolateUtils.run(() {
      final models =
          responseData
              .map(
                (json) =>
                    ProductModel.fromJson(Map<String, dynamic>.from(json)),
              )
              .toList();
      return models.map((m) => m.toEntity()).toList();
    });

    if (sortOption == CatalogSortOption.priceAsc) {
      entities.sort(
        (a, b) => (a.displaySalePrice ?? 0).compareTo(b.displaySalePrice ?? 0),
      );
    } else if (sortOption == CatalogSortOption.priceDesc) {
      entities.sort(
        (a, b) => (b.displaySalePrice ?? 0).compareTo(a.displaySalePrice ?? 0),
      );
    } else if (sortOption == CatalogSortOption.highStock) {
      entities.sort((a, b) => b.totalStock.compareTo(a.totalStock));
    }

    return (products: entities, totalCount: response.count);
  }

  Future<ProductEntity?> getProductById(String id) async {
    final response =
        await _supabase
            .from('products')
            .select(
              'id, name, is_active, description, category_id, brand_id, details, created_at, updated_at, stock_control, uses_batches, product_type, product_images(*), categories(name), brands(id, name, logo_url), warehouse_stock_batches(id, variant_id, warehouse_id, available_quantity, batch_number, expiry_date, product_id), product_variants(id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name))))',
            )
            .eq('id', id)
            .maybeSingle();

    if (response == null) return null;
    final model = ProductModel.fromJson(response);
    return model.toEntity();
  }

  Future<ProductVariantEntity?> getVariantById(String variantId) async {
    final response =
        await _supabase
            .from('product_variants')
            .select(
              'id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))',
            )
            .eq('id', variantId)
            .maybeSingle();

    if (response == null) return null;
    final model = ProductVariantModel.fromJson(response);
    return model.toEntity();
  }

  Future<List<VariantDraftEntity>> getVariantsDrafts(String productId) async {
    final response = await _supabase
        .from('product_variants')
        .select(
          'id, product_id, sku, barcode, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active, created_at, created_by, updated_by, product_images(*), variant_attribute_values(attribute_value_id, attribute_values(id, value, attributes(id, name)))',
        )
        .eq('product_id', productId)
        .eq('is_active', true)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response).map((json) {
      final model = ProductVariantModel.fromJson(json);
      return VariantDraftEntity.fromVariant(model.toEntity());
    }).toList();
  }

  Future<Map<String, dynamic>> getActiveProductsAndVariants() async {
    final response = await _supabase
        .from('products')
        .select(
          'id, name, is_active, product_variants(id, product_id, sku, barcode, sale_price, is_active)',
        )
        .eq('is_active', true);

    final rawList = List<Map<String, dynamic>>.from(response);
    final products = <Map<String, dynamic>>[];
    final variants = <Map<String, dynamic>>[];

    for (final product in rawList) {
      final pVariants = (product['product_variants'] as List<dynamic>?) ?? [];
      products.add({
        'id': product['id'],
        'name': product['name'],
        'is_active': product['is_active'],
      });
      variants.addAll(pVariants.map((v) => Map<String, dynamic>.from(v)));
    }

    return {'products': products, 'variants': variants};
  }

  Future<List<Map<String, dynamic>>> searchProductsForEntry(String term) async {
    final res = await _supabase
        .from('products')
        .select(
          'id, name, uses_batches, product_images!left(image_url), product_variants(id, product_id, sku, unit_cost, sale_price, is_active)',
        )
        .eq('is_active', true)
        .ilike('name', '%$term%')
        .eq('product_images.is_main', true)
        .limit(20);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> setProductActive(String productId, bool isActive) async {
    await _supabase
        .from('products')
        .update({'is_active': isActive})
        .eq('id', productId);
  }

  Future<List<String>> deleteProductSafely(String id) async {
    final response = await _supabase.rpc(
      'delete_product_safely',
      params: {'p_product_id': id},
    );
    return (response as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [];
  }

  Future<void> deleteVariant(String variantId) async {
    await _supabase.from('product_variants').delete().eq('id', variantId);
  }

  Future<void> deactivateVariant(String variantId) async {
    await _supabase
        .from('product_variants')
        .update({'is_active': false})
        .eq('id', variantId);
  }

  Future<void> saveProductComplete(Map<String, dynamic> jsonPayload) async {
    await _supabase.rpc(
      'save_product_complete',
      params: {'payload': jsonPayload},
    );
  }
}
