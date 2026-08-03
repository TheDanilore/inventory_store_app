import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@LazySingleton(as: WarehousesRepository)
class WarehousesRepositoryImpl implements WarehousesRepository {
  final SupabaseClient _supabase;

  WarehousesRepositoryImpl() : _supabase = Supabase.instance.client;

  @override
  Future<List<WarehouseEntity>> getActiveWarehouses() async {
    final response = await _supabase
        .from('warehouses')
        .select('*')
        .eq('is_active', true)
        .order('name');

    return (response as List<dynamic>)
        .map((e) => WarehouseModel.fromJson(e).toEntity())
        .toList();
  }

  @override
  Future<({List<WarehouseEntity> data, int count})> getWarehouses({
    required int start,
    required int end,
    String searchQuery = '',
  }) async {
    var selectQuery = _supabase.from('warehouses').select();
    var countQuery = _supabase.from('warehouses').select('id');

    if (searchQuery.isNotEmpty) {
      selectQuery = selectQuery.or(
        'name.ilike.%$searchQuery%,address.ilike.%$searchQuery%',
      );
      countQuery = countQuery.or(
        'name.ilike.%$searchQuery%,address.ilike.%$searchQuery%',
      );
    }

    final countRes = await countQuery.count(CountOption.exact);
    final totalRecords = countRes.count;

    final res = await selectQuery
        .order('name', ascending: true)
        .range(start, end);

    final data =
        (res as List<dynamic>)
            .map(
              (e) =>
                  WarehouseModel.fromJson(e as Map<String, dynamic>).toEntity(),
            )
            .toList();

    return (data: data, count: totalRecords);
  }

  @override
  Future<void> saveWarehouse({
    WarehouseEntity? existingWarehouse,
    required String name,
    required String address,
    required bool isActive,
  }) async {
    final authUserId = _supabase.auth.currentUser?.id;
    String? profileId;
    if (authUserId != null) {
      final p =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();
      profileId = p?['id'] as String?;
    }

    final payload = {
      'name': name.trim(),
      'address': address.trim().isNotEmpty ? address.trim() : null,
      'is_active': isActive,
    };

    if (existingWarehouse != null) {
      if (profileId != null) payload['updated_by'] = profileId;
      await _supabase
          .from('warehouses')
          .update(payload)
          .eq('id', existingWarehouse.id);
    } else {
      if (profileId != null) payload['created_by'] = profileId;
      await _supabase.from('warehouses').insert(payload);
    }
  }

  @override
  Future<void> toggleWarehouseStatus(WarehouseEntity wh, bool isActive) async {
    final authUserId = _supabase.auth.currentUser?.id;
    String? profileId;
    if (authUserId != null) {
      final p =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();
      profileId = p?['id'] as String?;
    }

    await _supabase
        .from('warehouses')
        .update({
          'is_active': isActive,
          if (profileId != null) 'updated_by': profileId,
        })
        .eq('id', wh.id);
  }

  @override
  Future<void> deleteWarehouse(String id) async {
    // 1. Validar lotes en el almacén
    final stockBatches = await _supabase
        .from('warehouse_stock_batches')
        .select('id')
        .eq('warehouse_id', id)
        .limit(1);
    if ((stockBatches as List).isNotEmpty) {
      throw Exception(
        'No se puede eliminar: El almacén tiene stock o historial de lotes registrado. Desactiva el almacén en su lugar.',
      );
    }

    // 2. Validar pedidos asociados
    final orders = await _supabase
        .from('orders')
        .select('id')
        .eq('warehouse_id', id)
        .limit(1);
    if ((orders as List).isNotEmpty) {
      throw Exception(
        'No se puede eliminar: Existen pedidos vinculados a este almacén. Desactiva el almacén en su lugar.',
      );
    }

    // 3. Validar entradas de inventario
    final entries = await _supabase
        .from('inventory_entries')
        .select('id')
        .eq('warehouse_id', id)
        .limit(1);
    if ((entries as List).isNotEmpty) {
      throw Exception(
        'No se puede eliminar: Existen entradas de inventario registradas en este almacén.',
      );
    }

    await _supabase.from('warehouses').delete().eq('id', id);
  }
}
