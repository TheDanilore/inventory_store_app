import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/inventory/data/models/kardex_movement_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/kardex_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@LazySingleton(as: KardexRepository)
class KardexRepositoryImpl implements KardexRepository {
  final SupabaseClient _supabase;

  // Caché L1 en memoria para Zero-Shimmer (TTL: 5 minutos)
  final Map<
    String,
    ({List<KardexMovementEntity> movements, int totalCount, DateTime timestamp})
  >
  _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  KardexRepositoryImpl(this._supabase);

  String _buildCacheKey({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
    String? batchId,
    int page = 0,
    int pageSize = 15,
  }) {
    return '${startDate?.toIso8601String()}_${endDate?.toIso8601String()}_${typeFilter}_${searchText}_${productId}_${variantId}_${batchId}_${page}_$pageSize';
  }

  void invalidateCache() {
    _cache.clear();
  }

  static const String _kardexProjection = '''
    id,
    variant_id,
    warehouse_id,
    stock_batch_id,
    order_id,
    inventory_entry_id,
    inventory_exit_id,
    physical_inventory_id,
    quantity,
    previous_stock,
    new_stock,
    unit_cost,
    total_cost,
    reason,
    notes,
    created_by,
    created_at,
    warehouses!inner(name),
    warehouse_stock_batches(batch_number),
    product_variants!inner(
      id,
      product_id,
      sku,
      variant_attribute_values(attribute_values(value)),
      product_images(image_url, is_main, variant_id),
      products!inner(id, name, uses_batches, product_images(image_url, is_main, variant_id))
    )
  ''';

  PostgrestFilterBuilder<T> _buildBaseQuery<T>(
    PostgrestFilterBuilder<T> query, {
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
    String? batchId,
  }) {
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      final endStr =
          endDate
              .add(const Duration(hours: 23, minutes: 59, seconds: 59))
              .toIso8601String();
      query = query.lte('created_at', endStr);
    }

    if (typeFilter == 'ENTRY') {
      query = query.not('inventory_entry_id', 'is', null);
    } else if (typeFilter == 'EXIT') {
      query = query.not('inventory_exit_id', 'is', null);
    } else if (typeFilter == 'SALE') {
      query = query.not('order_id', 'is', null).neq('reason', 'RETURN');
    } else if (typeFilter == 'RETURN') {
      query = query.not('order_id', 'is', null).eq('reason', 'RETURN');
    }

    // Filtrado estricto por lote (índice directo O(1))
    if (batchId != null && batchId.isNotEmpty) {
      query = query.eq('stock_batch_id', batchId);
    }

    // Filtrado estricto por variante (índice directo O(1)) y/o producto
    if (variantId != null && variantId.isNotEmpty) {
      query = query.eq('variant_id', variantId);
    } else if (productId != null && productId.isNotEmpty) {
      query = query.eq('product_variants.product_id', productId);
    } else if (searchText.isNotEmpty) {
      query = query.ilike('product_variants.products.name', '%$searchText%');
    }

    return query;
  }

  @override
  Future<({List<KardexMovementEntity> movements, int totalCount})>
  getKardexMovements({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
    String? batchId,
    int page = 0,
    int pageSize = 15,
  }) async {
    final cacheKey = _buildCacheKey(
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
      productId: productId,
      variantId: variantId,
      batchId: batchId,
      page: page,
      pageSize: pageSize,
    );

    // Consulta en caché L1
    final cached = _cache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      LoggerService.i(
        'Kardex L1 Cache Hit para clave: $cacheKey',
        tag: 'KardexRepo',
      );
      return (movements: cached.movements, totalCount: cached.totalCount);
    }

    var query = _supabase.from('inventory_movements').select(_kardexProjection);

    query = _buildBaseQuery(
      query,
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
      productId: productId,
      variantId: variantId,
      batchId: batchId,
    );

    final start = page * pageSize;
    final end = start + pageSize - 1;

    final response = await query
        .order('created_at', ascending: false)
        .range(start, end)
        .count(CountOption.exact);

    final dataList = response.data as List;
    final count = response.count;

    final movements =
        dataList
            .map((row) => KardexMovementModel.fromSupabaseRow(row).toEntity())
            .toList();

    // Guardar en caché L1
    _cache[cacheKey] = (
      movements: movements,
      totalCount: count,
      timestamp: DateTime.now(),
    );

    return (movements: movements, totalCount: count);
  }

  @override
  Future<List<KardexMovementEntity>> getAllKardexMovements({
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
    String? batchId,
  }) async {
    var query = _supabase.from('inventory_movements').select(_kardexProjection);

    query = _buildBaseQuery(
      query,
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
      productId: productId,
      variantId: variantId,
      batchId: batchId,
    );

    // Límite de seguridad para evitar desbordamiento de memoria (OOM) en exportación
    final response = await query
        .order('created_at', ascending: false)
        .limit(2000);
    final dataList = response as List;

    return dataList
        .map((row) => KardexMovementModel.fromSupabaseRow(row).toEntity())
        .toList();
  }
}
