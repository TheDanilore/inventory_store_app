import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_item_model.dart';
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
    // Calcular totales
    final double totalCost = items.fold(0, (sum, item) => sum + item.subtotal);

    // Obtener usuario
    String? createdByProfileId;
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', currentUser.id)
              .maybeSingle();
      createdByProfileId = profile?['id'] as String?;
    }

    // 1. ── Cabecera del ingreso ─────────────────────────────────────────
    final entryHeader =
        await _supabase
            .from('inventory_entries')
            .insert({
              'warehouse_id': warehouseId,
              'supplier_id': supplierId,
              'purchase_order_id': purchaseOrderId,
              'notes': notes.isEmpty ? null : notes,
              'created_by': createdByProfileId,
              'total_amount': totalCost,
              'document_type': documentType,
              'document_number':
                  documentNumber?.isEmpty ?? true ? null : documentNumber,
              'document_date': documentDate?.toIso8601String().split('T').first,
            })
            .select('id')
            .single();

    final entryId = entryHeader['id'] as String;

    for (final item in items) {
      // 2. ── inventory_entry_items ─────────────────────────────────────
      final entryItem = InventoryEntryItemModel(
        id: '',
        entryId: entryId,
        productId: item.productId,
        variantId: item.variantId,
        quantity: item.quantity,
        unitCost: item.unitCost,
        batchNumber: item.batchNumber,
        expiryDate: item.expiryDate,
      );
      await _supabase.from('inventory_entry_items').insert({
        ...entryItem.toJson()..remove('id'),
      });

      // 3. ── warehouse_stock_batches ────────────────────────────────────
      final existingBatch =
          await _supabase
              .from('warehouse_stock_batches')
              .select('id, available_quantity')
              .eq('variant_id', item.variantId)
              .eq('warehouse_id', warehouseId)
              .eq('batch_number', item.batchNumber)
              .maybeSingle();

      double previousStock = 0;
      double newStock = 0;
      String? stockBatchId;

      if (existingBatch != null) {
        stockBatchId = existingBatch['id'] as String;
        previousStock = (existingBatch['available_quantity'] as num).toDouble();
        newStock = previousStock + item.quantity;
        await _supabase
            .from('warehouse_stock_batches')
            .update({
              'available_quantity': newStock,
              'updated_at': DateTime.now().toIso8601String(),
              'updated_by': createdByProfileId,
            })
            .eq('id', stockBatchId);
      } else {
        newStock = item.quantity;
        final newBatch =
            await _supabase
                .from('warehouse_stock_batches')
                .insert({
                  'variant_id': item.variantId,
                  'warehouse_id': warehouseId,
                  'product_id': item.productId,
                  'supplier_id': supplierId,
                  'batch_number': item.batchNumber,
                  'expiry_date':
                      item.expiryDate?.toIso8601String().split('T').first,
                  'available_quantity': newStock,
                  'created_by': createdByProfileId,
                  'updated_by': createdByProfileId,
                })
                .select('id')
                .single();
        stockBatchId = newBatch['id'] as String;
      }

      // Actualizar unit_cost de la variante
      await _supabase
          .from('product_variants')
          .update({
            'unit_cost': item.unitCost,
            'updated_by': createdByProfileId,
          })
          .eq('id', item.variantId);

      // 4. ── inventory_movements (kardex) ──────────────────────────────
      await _supabase.from('inventory_movements').insert({
        'variant_id': item.variantId,
        'warehouse_id': warehouseId,
        'stock_batch_id': stockBatchId,
        'inventory_entry_id': entryId,
        'quantity': item.quantity,
        'previous_stock': previousStock,
        'new_stock': newStock,
        'unit_cost': item.unitCost,
        'total_cost': item.subtotal,
        'reason': 'ENTRY',
        'notes': notes.isEmpty ? null : notes,
        'created_by': createdByProfileId,
      });
    }

    // 5. ── Movimiento financiero o crédito (SOLO SI ES INGRESO MANUAL) ────
    if (purchaseOrderId == null) {
      if (paymentMode == 'CONTADO' && accountId != null) {
        // Obtenemos los datos de la cuenta para validar saldo antes de debitar
        final accountDataResp =
            await _supabase
                .from('financial_accounts')
                .select('balance')
                .eq('id', accountId)
                .maybeSingle();

        if (accountDataResp != null) {
          final accountBalance = (accountDataResp['balance'] as num).toDouble();

          String supplierName = '';
          if (supplierId != null) {
            final supResp =
                await _supabase
                    .from('suppliers')
                    .select('name')
                    .eq('id', supplierId)
                    .maybeSingle();
            if (supResp != null) supplierName = supResp['name'] as String;
          }

          await _supabase.from('account_movements').insert({
            'account_id': accountId,
            'movement_type': 'EXPENSE',
            'amount': totalCost,
            'description':
                'Compra de inventario${supplierName.isNotEmpty ? ' · $supplierName' : ''}',
            'reference_type': 'inventory_entry',
            'reference_id': entryId,
            'created_by': createdByProfileId,
            'shift_id': activeShiftId,
          });

          await _supabase
              .from('financial_accounts')
              .update({'balance': accountBalance - totalCost})
              .eq('id', accountId);
        }
      } else if (paymentMode == 'CRÉDITO' && supplierId != null) {
        var creditResp =
            await _supabase
                .from('supplier_credits')
                .select('id, current_debt')
                .eq('supplier_id', supplierId)
                .maybeSingle();

        String supplierCreditId;
        if (creditResp == null) {
          final newCredit =
              await _supabase
                  .from('supplier_credits')
                  .insert({
                    'supplier_id': supplierId,
                    'current_debt': totalCost,
                    'created_by': createdByProfileId,
                  })
                  .select('id')
                  .single();
          supplierCreditId = newCredit['id'] as String;
        } else {
          supplierCreditId = creditResp['id'] as String;
          final currentDebt = (creditResp['current_debt'] as num).toDouble();
          await _supabase
              .from('supplier_credits')
              .update({
                'current_debt': currentDebt + totalCost,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', supplierCreditId);
        }

        await _supabase.from('supplier_credit_movements').insert({
          'supplier_credit_id': supplierCreditId,
          'purchase_order_id': purchaseOrderId,
          'movement_type': 'CHARGE',
          'amount': totalCost,
          'notes': 'Compra a crédito — Entrada #$entryId',
          'created_by': createdByProfileId,
        });
      }
    }

    // 6. ── Actualizar purchase_order si viene de una ─────────────────
    if (purchaseOrderId != null && purchaseOrderId.isNotEmpty) {
      try {
        await syncPurchaseOrderItemsAndStatus(_supabase, purchaseOrderId);
      } catch (e) {
        // Log de error de actualización de orden sin bloquear el ingreso de inventario
      }
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
