import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';

import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';

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
    final itemsJson = items.map((e) => {
      'productId': e.productId,
      'variantId': e.variantId,
      'quantity': e.quantity,
      'unitCost': e.unitCost,
      'batchNumber': e.batchNumber,
      'expiryDate': e.expiryDate?.toIso8601String(),
    }).toList();

    try {
      await _supabase.rpc('process_inventory_entry_rpc', params: {
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
      });
    } on PostgrestException catch (e) {
      debugPrint('[InventoryEntriesRepo] createInventoryEntry error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('[InventoryEntriesRepo] createInventoryEntry unexpected error: $e');
      rethrow;
    }
  }

  static Future<void> syncPurchaseOrderItemsAndStatus(
    SupabaseClient supabase,
    String purchaseOrderId,
  ) async {
    debugPrint('[syncPurchaseOrder] Starting sync for PO: $purchaseOrderId');

    // 0. Nunca recalcular el estado de una orden ya anulada. Este método
    //    se invoca también desde lecturas (fetchOrderItems), así que sin
    //    este guard, con solo abrir el detalle de una orden CANCELLED se
    //    la "resucitaba" a SENT/PARTIAL/RECEIVED.
    try {
      final currentPo =
          await supabase
              .from('purchase_orders')
              .select('status')
              .eq('id', purchaseOrderId)
              .maybeSingle();
      if (currentPo != null && currentPo['status'] == 'CANCELLED') {
        debugPrint(
          '[syncPurchaseOrder] PO $purchaseOrderId is CANCELLED, skipping sync.',
        );
        return;
      }
    } catch (e) {
      debugPrint('[syncPurchaseOrder] Could not check current status: $e');
    }

    // 1. Intentar primero con la RPC con SECURITY DEFINER (para ignorar RLS)
    try {
      final rpcResult = await supabase.rpc(
        'sync_purchase_order_reception_rpc',
        params: {'p_purchase_order_id': purchaseOrderId},
      );
      debugPrint('[syncPurchaseOrder] RPC Result: $rpcResult');
      if (rpcResult != null && rpcResult['success'] == true) {
        return;
      }
    } catch (e) {
      debugPrint(
        '[syncPurchaseOrder] RPC failed or not installed: $e. Falling back to direct update...',
      );
    }

    // 2. No se usa fallback de cliente. La sincronización se delega 
    // completamente al backend (RPC y base de datos).
  }

  Future<List<Map<String, dynamic>>> getActiveWarehouses() async {
    return await _supabase
        .from('warehouses')
        .select('id, name')
        .eq('is_active', true);
  }

  Future<List<Map<String, dynamic>>> getActiveSuppliers() async {
    return await _supabase
        .from('suppliers')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
  }

  Future<List<Map<String, dynamic>>> getActiveAccounts() async {
    return await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance')
        .eq('is_active', true)
        .order('name');
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
  }

  @override
  Future<List<dynamic>> getEntryItems(String entryId) async {
      final resp = await _supabase
        .from('inventory_entry_items')
        .select('''
          quantity, unit_cost, batch_number, expiry_date, variant_id,
          products!inner(
            name, 
            uses_batches
          ),
          product_variants!inner(
            variant_attribute_values(
              attribute_values(value)
            )
          )
        ''')
        .eq('entry_id', entryId);
    return resp as List<dynamic>;
  }
}
