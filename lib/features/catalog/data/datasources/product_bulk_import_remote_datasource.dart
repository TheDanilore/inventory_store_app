import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';

class ProductBulkImportRemoteDataSource {
  final SupabaseClient _supabase;

  ProductBulkImportRemoteDataSource(this._supabase);

  Future<ImportCatalogContext> getImportCatalogContext() async {
    Future<List<String>> allNames(String table) async {
      final out = <String>[];
      const page = 1000;
      for (var from = 0; ; from += page) {
        final res = await _supabase
            .from(table)
            .select('name')
            .order('name')
            .range(from, from + page - 1);
        final rows = List<Map<String, dynamic>>.from(res);
        out.addAll(rows.map((r) => (r['name'] ?? '').toString()));
        if (rows.length < page) break;
      }
      return out;
    }

    final warehousesRes = await _supabase
        .from('warehouses')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    final brands = await allNames('brands');
    final categories = await allNames('categories');

    return ImportCatalogContext(
      warehouses:
          List<Map<String, dynamic>>.from(warehousesRes)
              .map(
                (w) => ImportWarehouse(
                  id: w['id'].toString(),
                  name: (w['name'] ?? '').toString(),
                ),
              )
              .toList(),
      brandNames: brands,
      categoryNames: categories,
    );
  }

  Future<List<ExistingVariant>> findExistingVariants({
    required List<String> productNames,
    required List<String> skus,
    required String? warehouseId,
  }) async {
    const chunk = 150;
    final names = productNames.map(normalizeKey).toSet().toList();
    final skuList =
        skus
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

    final found = <String, ExistingVariant>{};

    Future<void> run(List<String> n, List<String> k) async {
      final res = await _supabase.rpc(
        'find_existing_variants_for_import',
        params: {'p_names': n, 'p_skus': k, 'p_warehouse_id': warehouseId},
      );
      for (final row in List<Map<String, dynamic>>.from(res as List)) {
        final id = row['variant_id'].toString();
        found[id] = ExistingVariant(
          variantId: id,
          productId: row['product_id'].toString(),
          productName: (row['product_name'] ?? '').toString(),
          brandName: (row['brand_name'] ?? '').toString(),
          sku: (row['sku'] ?? '').toString(),
          variantName: (row['variant_name'] ?? '').toString(),
          usesLots: row['uses_lots'] == true,
          currentStock: ((row['current_stock'] ?? 0) as num).round(),
        );
      }
    }

    for (var i = 0; i < names.length; i += chunk) {
      await run(
        names.sublist(i, i + chunk > names.length ? names.length : i + chunk),
        const [],
      );
    }
    for (var i = 0; i < skuList.length; i += chunk) {
      await run(
        const [],
        skuList.sublist(
          i,
          i + chunk > skuList.length ? skuList.length : i + chunk,
        ),
      );
    }
    return found.values.toList();
  }

  Future<ImportBatchResult> importCatalogBatch({
    required List<Map<String, dynamic>> products,
    required String? warehouseId,
    required String stockMode,
    required bool updatePrices,
    required String batchId,
  }) async {
    final res = await _supabase.rpc(
      'import_catalog_batch_v2',
      params: {
        'p_products': products,
        'p_warehouse_id': warehouseId,
        'p_stock_mode': stockMode,
        'p_update_prices': updatePrices,
        'p_batch_id': batchId,
      },
    );
    final m = Map<String, dynamic>.from(res as Map);
    int n(String k) => ((m[k] ?? 0) as num).toInt();
    return ImportBatchResult(
      createdProducts: n('created_products'),
      createdVariants: n('created_variants'),
      updatedVariants: n('updated_variants'),
      stockMovements: n('stock_movements'),
    );
  }
}
