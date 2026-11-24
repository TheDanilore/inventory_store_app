import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_model.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

abstract class SuppliersRemoteDataSource {
  Future<SuppliersPageEntity> fetchSuppliersPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
    bool includeStats = true,
  });

  Future<List<SupplierEntity>> getActiveSuppliers();

  Future<SupplierEntity?> toggleSupplierStatus(
    String supplierId,
    bool currentStatus,
  );

  Future<List<SupplierEntity>> bulkToggleSuppliersStatus(
    List<String> supplierIds,
  );

  Future<SupplierEntity> createSupplier(SupplierEntity supplier);

  Future<SupplierEntity> updateSupplier(SupplierEntity supplier);
}

@LazySingleton(as: SuppliersRemoteDataSource)
class SuppliersRemoteDataSourceImpl implements SuppliersRemoteDataSource {
  final SupabaseClient _supabase;
  static const Duration _timeout = Duration(seconds: 15);
  static const String _tag = 'SUPPLIERS_DS';
  static const String _selectColumns =
      'id, name, tax_id, contact_name, phone, email, address, is_active, created_at';

  SuppliersRemoteDataSourceImpl(this._supabase);

  bool _isMissingRpc(PostgrestException e) {
    return e.code == 'PGRST202' ||
        e.code == '42883' ||
        e.message.contains('Could not find the function');
  }

  String _sanitizePostgrestToken(String input) {
    return input.trim().replaceAll(RegExp(r'[,()]'), ' ');
  }

  @override
  Future<SuppliersPageEntity> fetchSuppliersPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
    bool includeStats = true,
  }) async {
    final trimmed = searchQuery.trim();
    final offset = page * pageSize;

    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'get_suppliers_page_rpc',
            params: {
              'p_search_query': trimmed,
              'p_is_active': filterIsActive,
              'p_limit': pageSize,
              'p_offset': offset,
              'p_include_stats': includeStats,
            },
          )
          .timeout(_timeout);

      final map = rpcRes as Map<String, dynamic>? ?? const {};
      final rawItems = (map['items'] as List<dynamic>?) ?? const [];
      final suppliers =
          rawItems
              .map(
                (item) =>
                    SupplierModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false);
      final rawStats = map['stats'] as Map<String, dynamic>?;
      final stats =
          rawStats != null ? SupplierStatsModel.fromJson(rawStats) : null;
      final totalCount = (map['totalCount'] as num?)?.toInt() ?? 0;

      return SuppliersPageEntity(
        suppliers: suppliers,
        totalCount: totalCount,
        stats: stats,
      );
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'get_suppliers_page_rpc no disponible aún; usando fallback PostgREST.',
        tag: _tag,
      );
      return _fetchSuppliersPageFallback(
        page: page,
        pageSize: pageSize,
        searchQuery: trimmed,
        filterIsActive: filterIsActive,
      );
    }
  }

  Future<SuppliersPageEntity> _fetchSuppliersPageFallback({
    required int page,
    required int pageSize,
    required String searchQuery,
    required bool? filterIsActive,
  }) async {
    var query = _supabase.from('suppliers').select(_selectColumns);

    final sanitized = _sanitizePostgrestToken(searchQuery);
    if (sanitized.isNotEmpty) {
      query = query.or(
        'name.ilike.%$sanitized%,tax_id.ilike.%$sanitized%,contact_name.ilike.%$sanitized%,phone.ilike.%$sanitized%',
      );
    }
    if (filterIsActive != null) {
      query = query.eq('is_active', filterIsActive);
    }

    final start = page * pageSize;
    final end = start + pageSize - 1;

    final response = await query
        .order('name', ascending: true)
        .range(start, end)
        .count(CountOption.exact)
        .timeout(_timeout);

    final list =
        (response.data as List<dynamic>)
            .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);

    return SuppliersPageEntity(
      suppliers: list,
      totalCount: response.count,
      stats: null,
    );
  }

  @override
  Future<List<SupplierEntity>> getActiveSuppliers() async {
    final response = await _supabase
        .from('suppliers')
        .select(_selectColumns)
        .eq('is_active', true)
        .order('name')
        .timeout(_timeout);

    return (response as List<dynamic>)
        .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<SupplierEntity?> toggleSupplierStatus(
    String supplierId,
    bool currentStatus,
  ) async {
    final nextStatus = !currentStatus;
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'rpc_toggle_supplier_status',
            params: {'p_supplier_id': supplierId, 'p_is_active': nextStatus},
          )
          .timeout(_timeout);

      final res = rpcRes as Map<String, dynamic>?;
      if (res?['success'] != true) {
        throw PostgrestException(
          message:
              res?['error']?.toString() ?? 'Error al cambiar estado del proveedor.',
          code: res?['detail']?.toString() ?? 'P0001',
        );
      }

      final supJson = res?['supplier'] as Map<String, dynamic>?;
      return supJson != null ? SupplierModel.fromJson(supJson) : null;
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'rpc_toggle_supplier_status no disponible; usando fallback update.',
        tag: _tag,
      );
      await _supabase
          .from('suppliers')
          .update({'is_active': nextStatus})
          .eq('id', supplierId)
          .timeout(_timeout);
      return null;
    }
  }

  @override
  Future<List<SupplierEntity>> bulkToggleSuppliersStatus(
    List<String> supplierIds,
  ) async {
    if (supplierIds.isEmpty) return const [];
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'rpc_bulk_toggle_suppliers_status',
            params: {'p_supplier_ids': supplierIds},
          )
          .timeout(_timeout);

      final res = rpcRes as Map<String, dynamic>?;
      if (res?['success'] != true) {
        throw PostgrestException(
          message:
              res?['error']?.toString() ??
              'Error al actualizar estado masivo de proveedores.',
          code: res?['detail']?.toString() ?? 'P0001',
        );
      }

      final rawList = (res?['updatedSuppliers'] as List<dynamic>?) ?? const [];
      return rawList
          .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'rpc_bulk_toggle_suppliers_status no disponible; ejecutando fallback secuencial.',
        tag: _tag,
      );
      final rows = await _supabase
          .from('suppliers')
          .select(_selectColumns)
          .inFilter('id', supplierIds)
          .timeout(_timeout);

      final updated = <SupplierEntity>[];
      for (final row in (rows as List<dynamic>)) {
        final s = SupplierModel.fromJson(row as Map<String, dynamic>);
        final resp = await _supabase
            .from('suppliers')
            .update({'is_active': !s.isActive})
            .eq('id', s.id)
            .select(_selectColumns)
            .single()
            .timeout(_timeout);
        updated.add(SupplierModel.fromJson(resp));
      }
      return updated;
    }
  }

  @override
  Future<SupplierEntity> createSupplier(SupplierEntity supplier) async {
    return _upsertSupplier(supplier, isNew: true);
  }

  @override
  Future<SupplierEntity> updateSupplier(SupplierEntity supplier) async {
    return _upsertSupplier(supplier, isNew: false);
  }

  Future<SupplierEntity> _upsertSupplier(
    SupplierEntity supplier, {
    required bool isNew,
  }) async {
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'rpc_upsert_supplier',
            params: {
              'p_id': isNew ? null : supplier.id,
              'p_name': supplier.name,
              'p_tax_id': supplier.taxId,
              'p_contact_name': supplier.contactName,
              'p_phone': supplier.phone,
              'p_email': supplier.email,
              'p_address': supplier.address,
              'p_is_active': supplier.isActive,
            },
          )
          .timeout(_timeout);

      final res = rpcRes as Map<String, dynamic>?;
      if (res?['success'] != true) {
        throw PostgrestException(
          message: res?['error']?.toString() ?? 'Error al guardar proveedor.',
          code: res?['detail']?.toString() ?? 'P0001',
        );
      }

      return SupplierModel.fromJson(res!['supplier'] as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'rpc_upsert_supplier no disponible; usando fallback PostgREST.',
        tag: _tag,
      );
      final model = SupplierModel(
        id: isNew ? '' : supplier.id,
        name: supplier.name.trim(),
        taxId:
            supplier.taxId?.trim().isEmpty == true
                ? null
                : supplier.taxId?.trim(),
        contactName: supplier.contactName?.trim(),
        phone: supplier.phone?.trim(),
        email: supplier.email?.trim(),
        address: supplier.address?.trim(),
        isActive: supplier.isActive,
      );

      final response =
          isNew
              ? await _supabase
                  .from('suppliers')
                  .insert(model.toJson())
                  .select(_selectColumns)
                  .single()
                  .timeout(_timeout)
              : await _supabase
                  .from('suppliers')
                  .update(model.toJson())
                  .eq('id', supplier.id)
                  .select(_selectColumns)
                  .single()
                  .timeout(_timeout);

      return SupplierModel.fromJson(response);
    }
  }
}
