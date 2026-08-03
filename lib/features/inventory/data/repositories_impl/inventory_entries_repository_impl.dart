import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';

import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';
import 'dart:developer' as developer;

@LazySingleton(as: InventoryEntriesRepository)
class InventoryEntriesRepositoryImpl implements InventoryEntriesRepository {
  final _supabase = Supabase.instance.client;

  @override
  Future<void> createInventoryEntry({
    required List<InventoryEntryItemEntity> items,
    required String warehouseId,
    required String? supplierId,
    required String? purchaseOrderId,
    required String paymentMode,
    required String? accountId,
    required String? activeShiftId,
    required String documentType,
    required String? documentNumber,
    required DateTime? documentDate,
    required String notes,
  }) async {
    final itemsJson =
        items
            .map(
              (e) => {
                'productId': e.productId,
                'variantId': e.variantId,
                'quantity': e.quantity,
                'unitCost': e.unitCost,
                'batchNumber': e.batchNumber,
                'expiryDate': e.expiryDate?.toIso8601String(),
              },
            )
            .toList();

    try {
      await _supabase.rpc(
        'process_inventory_entry_rpc',
        params: {
          'p_warehouse_id': warehouseId,
          'p_supplier_id': supplierId,
          'p_purchase_order_id': purchaseOrderId,
          'p_payment_mode': paymentMode,
          'p_account_id': accountId,
          'p_active_shift_id': null, // Validation moved to server RPC
          'p_document_type': documentType,
          'p_document_number': documentNumber,
          'p_document_date': documentDate?.toIso8601String().split('T').first,
          'p_notes': notes,
          'p_items': itemsJson,
        },
      );
    } on PostgrestException catch (e, st) {
      developer.log(
        '[InventoryEntriesRepo] createInventoryEntry error: ${e.message}',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
      throw Exception(e.message);
    } catch (e, st) {
      developer.log(
        '[InventoryEntriesRepo] createInventoryEntry unexpected error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
      rethrow;
    }
  }

  static Future<void> syncPurchaseOrderItemsAndStatus(
    SupabaseClient supabase,
    String purchaseOrderId,
  ) async {
    developer.log(
      '[syncPurchaseOrder] Starting sync for PO: $purchaseOrderId',
      name: 'InventoryEntriesRepositoryImpl',
    );

    // 0. Nunca recalcular el estado de una orden ya anulada.
    try {
      final currentPo =
          await supabase
              .from('purchase_orders')
              .select('status')
              .eq('id', purchaseOrderId)
              .maybeSingle();
      if (currentPo != null && currentPo['status'] == 'CANCELLED') {
        developer.log(
          '[syncPurchaseOrder] PO $purchaseOrderId is CANCELLED, skipping sync.',
          name: 'InventoryEntriesRepositoryImpl',
        );
        return;
      }
    } catch (e, st) {
      developer.log(
        '[syncPurchaseOrder] Could not check current status',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
    }

    // 1. Intentar primero con la RPC con SECURITY DEFINER (para ignorar RLS)
    try {
      final rpcResult = await supabase.rpc(
        'sync_purchase_order_reception_rpc',
        params: {'p_purchase_order_id': purchaseOrderId},
      );
      developer.log(
        '[syncPurchaseOrder] RPC Result: $rpcResult',
        name: 'InventoryEntriesRepositoryImpl',
      );
      if (rpcResult != null && rpcResult['success'] == true) {
        return;
      }
    } catch (e, st) {
      developer.log(
        '[syncPurchaseOrder] RPC failed or not installed. Falling back to direct update...',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
    }

    // 2. No se usa fallback de cliente. La sincronización se delega completamente al backend.
  }

  Future<List<Map<String, dynamic>>> getActiveWarehouses() async {
    try {
      return await _supabase
          .from('warehouses')
          .select('id, name')
          .eq('is_active', true);
    } catch (e, st) {
      developer.log(
        'getActiveWarehouses error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveSuppliers() async {
    try {
      return await _supabase
          .from('suppliers')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
    } catch (e, st) {
      developer.log(
        'getActiveSuppliers error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveAccounts() async {
    try {
      return await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');
    } catch (e, st) {
      developer.log(
        'getActiveAccounts error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
      rethrow;
    }
  }

  @override
  Future<({List<InventoryEntryEntity> data, int count})> getEntries({
    required int start,
    required int end,
    String? searchQuery,
    String? warehouseFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('inventory_entries').select('''
          id, created_at, notes, total_amount,
          document_type, document_number, document_date, purchase_order_id,
          warehouses!inner(name),
          suppliers(name)
        ''');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Usamos or para buscar en notas o en nombre del proveedor
        // Nota: Si queremos buscar en la tabla relacionada suppliers, supabase postgrest tiene limitaciones con or en relaciones
        // Pero si usamos .ilike('suppliers.name') requiere inner join con !inner, lo cual descarta las entradas sin proveedor.
        // Si la búsqueda incluye el número de documento:
        query = query.or(
          'document_number.ilike.%$searchQuery%,notes.ilike.%$searchQuery%',
        );
      }

      if (warehouseFilter != null && warehouseFilter != 'Todos') {
        query = query.eq('warehouses.name', warehouseFilter);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte(
          'created_at',
          endDate.add(const Duration(days: 1)).toIso8601String(),
        );
      }

      final resp = await query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      final data =
          (resp.data as List<dynamic>)
              .map((e) => InventoryEntryModel.fromJson(e).toEntity())
              .toList();
      return (data: data, count: resp.count);
    } catch (e, st) {
      developer.log(
        'getEntries error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> getEntryItems(String entryId) async {
    try {
      final resp = await _supabase
          .from('inventory_entry_items')
          .select('''
          id, product_id, quantity, unit_cost, batch_number, expiry_date, variant_id,
          products(
            id,
            name, 
            uses_batches,
            product_images(*)
          ),
          product_variants(
            id,
            product_images(*),
            variant_attribute_values(
              attribute_values(value)
            )
          )
        ''')
          .eq('entry_id', entryId);
      return resp as List<dynamic>;
    } catch (e, st) {
      developer.log(
        'getEntryItems error',
        error: e,
        stackTrace: st,
        name: 'InventoryEntriesRepositoryImpl',
      );
      rethrow;
    }
  }
}
