import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/entry_item_ui.dart';
import 'package:inventory_store_app/models/inventory_entry_item_model.dart';

class InventoryEntriesService {
  final _supabase = Supabase.instance.client;

  Future<void> createInventoryEntry({
    required List<EntryItemUI> items,
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
        productId: item.product.id,
        variantId: item.variant.id,
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
              .eq('variant_id', item.variant.id)
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
                  'variant_id': item.variant.id,
                  'warehouse_id': warehouseId,
                  'product_id': item.product.id,
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
          .eq('id', item.variant.id);

      // 4. ── inventory_movements (kardex) ──────────────────────────────
      await _supabase.from('inventory_movements').insert({
        'variant_id': item.variant.id,
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
      } else if (paymentMode == 'CREDITO' && supplierId != null) {
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
    if (purchaseOrderId != null) {
      final poItems = await _supabase
          .from('purchase_order_items')
          .select('id, variant_id, quantity_ordered, quantity_received')
          .eq('purchase_order_id', purchaseOrderId);

      bool allReceived = true;

      for (final poi in poItems as List) {
        final poiId = poi['id'] as String;
        final variantId = poi['variant_id'] as String;
        final ordered = (poi['quantity_ordered'] as num).toDouble();
        double received = (poi['quantity_received'] as num).toDouble();

        final sumReceivedNow = items
            .where((i) => i.variant.id == variantId)
            .fold(0.0, (s, i) => s + i.quantity);

        if (sumReceivedNow > 0) {
          received += sumReceivedNow;
          await _supabase
              .from('purchase_order_items')
              .update({'quantity_received': received})
              .eq('id', poiId);
        }

        if (received < ordered) {
          allReceived = false;
        }
      }

      await _supabase
          .from('purchase_orders')
          .update({
            'status': allReceived ? 'RECEIVED' : 'PARTIAL',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', purchaseOrderId);
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
    return await _supabase.from('financial_accounts').select('id, name, type, balance').eq('is_active', true).order('name');
  }

  Future<Map<String, dynamic>> getEntries({
    required int start,
    required int end,
    String? searchQuery,
    String? warehouseFilter,
    DateTimeRange? dateRange,
  }) async {
    var query = _supabase
        .from('inventory_entries')
        .select('''
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
      query = query.or('document_number.ilike.%$searchQuery%,notes.ilike.%$searchQuery%');
    }

    if (warehouseFilter != null && warehouseFilter != 'Todos') {
      query = query.eq('warehouses.name', warehouseFilter);
    }

    if (dateRange != null) {
      query = query
          .gte('created_at', dateRange.start.toIso8601String())
          .lte('created_at', dateRange.end.add(const Duration(days: 1)).toIso8601String());
    }

    final resp = await query.order('created_at', ascending: false).range(start, end).count(CountOption.exact);

    return {
      'data': resp.data as List<dynamic>,
      'count': resp.count,
    };
  }

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
