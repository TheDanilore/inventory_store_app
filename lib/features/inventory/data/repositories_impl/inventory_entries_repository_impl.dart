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
        'p_active_shift_id': activeShiftId,
        'p_document_type': documentType,
        'p_document_number': documentNumber,
        'p_document_date': documentDate?.toIso8601String().split('T').first,
        'p_notes': notes,
        'p_items': itemsJson,
      });
    } catch (e) {
      if (e.toString().contains('Saldo insuficiente')) {
        throw Exception('Saldo insuficiente en la cuenta financiera.');
      }
      if (e.toString().contains('La caja seleccionada no tiene un turno abierto')) {
        throw Exception('La caja seleccionada no tiene un turno abierto.');
      }
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

    // 2. Fallback de cliente
    final poItems = await supabase
        .from('purchase_order_items')
        .select(
          'id, product_id, variant_id, quantity_ordered, quantity_received',
        )
        .eq('purchase_order_id', purchaseOrderId);

    final poItemsList = poItems as List;
    if (poItemsList.isEmpty) {
      debugPrint('[syncPurchaseOrder] PO has no items.');
      return;
    }

    final entryItemsResp = await supabase
        .from('inventory_entry_items')
        .select(
          'product_id, variant_id, quantity, inventory_entries!inner(purchase_order_id)',
        )
        .eq('inventory_entries.purchase_order_id', purchaseOrderId);

    final entryItemsList = entryItemsResp as List;
    debugPrint(
      '[syncPurchaseOrder] Found ${entryItemsList.length} entry item records for PO.',
    );

    bool allReceived = true;
    bool anyReceived = false;

    for (final poi in poItemsList) {
      final poiId = poi['id'] as String;
      final productId = poi['product_id'] as String?;
      final variantId = poi['variant_id'] as String?;
      final ordered = (poi['quantity_ordered'] as num?)?.toDouble() ?? 0.0;

      final totalReceived = entryItemsList
          .where((ei) {
            final eiVariantId = ei['variant_id'] as String?;
            final eiProductId = ei['product_id'] as String?;
            if (variantId != null &&
                variantId.isNotEmpty &&
                eiVariantId != null &&
                eiVariantId.isNotEmpty &&
                variantId == eiVariantId) {
              return true;
            }
            if (productId != null &&
                productId.isNotEmpty &&
                eiProductId != null &&
                eiProductId.isNotEmpty &&
                productId == eiProductId) {
              return true;
            }
            return false;
          })
          .fold(
            0.0,
            (sum, ei) => sum + ((ei['quantity'] as num?)?.toDouble() ?? 0.0),
          );

      debugPrint(
        '[syncPurchaseOrder] Item $poiId -> ordered=$ordered, totalReceived=$totalReceived',
      );

      try {
        await supabase
            .from('purchase_order_items')
            .update({'quantity_received': totalReceived})
            .eq('id', poiId);
      } catch (e) {
        debugPrint(
          '[syncPurchaseOrder] Error updating item $poiId (RLS Policy Issue): $e',
        );
      }

      if (totalReceived > 0) anyReceived = true;
      if (totalReceived < ordered) allReceived = false;
    }

    final String newStatus =
        allReceived ? 'RECEIVED' : (anyReceived ? 'PARTIAL' : 'SENT');

    debugPrint(
      '[syncPurchaseOrder] Updating PO $purchaseOrderId status -> $newStatus (allReceived=$allReceived, anyReceived=$anyReceived)',
    );

    try {
      await supabase
          .from('purchase_orders')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', purchaseOrderId);
    } catch (e) {
      debugPrint(
        '[syncPurchaseOrder] Error updating PO status (RLS Policy Issue): $e',
      );
    }
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
          suppliers(name),
          inventory_entry_items(id)
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
            uses_batches, 
            product_images(image_url, is_main, variant_id)
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
