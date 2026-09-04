import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/inventory/data/models/kardex_movement_model.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/kardex_repository.dart';

@LazySingleton(as: KardexRepository)
class KardexRepositoryImpl implements KardexRepository {
  final SupabaseClient _supabase;

  KardexRepositoryImpl(this._supabase);

  PostgrestFilterBuilder<T> _buildBaseQuery<T>(
    PostgrestFilterBuilder<T> query, {
    DateTime? startDate,
    DateTime? endDate,
    String typeFilter = 'ALL',
    String searchText = '',
    String? productId,
    String? variantId,
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

    // Filtrado estricto por variante (índice directo O(1)) y/o producto
    if (variantId != null && variantId.isNotEmpty) {
      query = query.eq('variant_id', variantId);
    } else if (productId != null && productId.isNotEmpty) {
      query = query.eq('product_variants.product_id', productId);
    } else if (searchText.isNotEmpty) {
      // Usamos el filtro de tabla foránea soportado por PostgREST para ilike.
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
    int page = 0,
    int pageSize = 12,
  }) async {
    var query = _supabase.from('inventory_movements').select('''
      *,
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
    ''');

    query = _buildBaseQuery(
      query,
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
      productId: productId,
      variantId: variantId,
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
  }) async {
    var query = _supabase.from('inventory_movements').select('''
      *,
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
    ''');

    query = _buildBaseQuery(
      query,
      startDate: startDate,
      endDate: endDate,
      typeFilter: typeFilter,
      searchText: searchText,
      productId: productId,
      variantId: variantId,
    );

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map((row) => KardexMovementModel.fromSupabaseRow(row).toEntity())
        .toList();
  }
}
