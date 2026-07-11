import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@LazySingleton(as: WarehousesRepository)
class WarehousesRepositoryImpl implements WarehousesRepository {
  final SupabaseClient _supabase;

  WarehousesRepositoryImpl() : _supabase = Supabase.instance.client;

  @override
  Future<Map<String, dynamic>> getWarehouses({
    required int start,
    required int end,
    String searchQuery = '',
  }) async {
    var selectQuery = _supabase.from('warehouses').select();
    var countQuery = _supabase.from('warehouses').select('id');

    if (searchQuery.isNotEmpty) {
      selectQuery = selectQuery.or('name.ilike.%$searchQuery%,address.ilike.%$searchQuery%');
      countQuery = countQuery.or('name.ilike.%$searchQuery%,address.ilike.%$searchQuery%');
    }

    final countRes = await countQuery.count(CountOption.exact);
    final totalRecords = countRes.count;

    final res = await selectQuery
        .order('name', ascending: true)
        .range(start, end);

    return {
      'data': res,
      'count': totalRecords,
    };
  }

  @override
  Future<void> saveWarehouse({
    WarehouseModel? existingWarehouse,
    required String name,
    required String address,
    required bool isActive,
  }) async {
    final authUserId = _supabase.auth.currentUser?.id;
    String? profileId;
    if (authUserId != null) {
      final p = await _supabase
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
          .eq('id', existingWarehouse.id!);
    } else {
      if (profileId != null) payload['created_by'] = profileId;
      await _supabase.from('warehouses').insert(payload);
    }
  }

  @override
  Future<void> toggleWarehouseStatus(WarehouseModel wh, bool isActive) async {
    final authUserId = _supabase.auth.currentUser?.id;
    String? profileId;
    if (authUserId != null) {
      final p = await _supabase
          .from('profiles')
          .select('id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();
      profileId = p?['id'] as String?;
    }

    await _supabase.from('warehouses').update({
      'is_active': isActive,
      if (profileId != null) 'updated_by': profileId,
    }).eq('id', wh.id!);
  }
}
