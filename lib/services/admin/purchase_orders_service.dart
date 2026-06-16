import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/purchase_order_model.dart';
import 'package:inventory_store_app/models/purchase_order_item_model.dart';
import 'package:inventory_store_app/models/variant_attribute_value_model.dart';

class PurchaseOrdersService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches a paginated list of purchase orders with optional filters.
  Future<Map<String, dynamic>> fetchOrders({
    required int page,
    required int pageSize,
    String searchText = '',
    String statusFilter = 'Todos',
    DateTimeRange? dateRange,
  }) async {
    final start = page * pageSize;
    final end = start + pageSize - 1;

    var query = _supabase.from('purchase_orders').select('''
          id, created_at, supplier_id, supplier_name,
          status, total_amount, payment_method, payment_status,
          amount_paid, due_date, discount_amount, tax_amount,
          document_type, document_number, notes,
          suppliers!left(name),
          warehouses!left(name),
          purchase_order_items(count)
        ''');

    // 1. Filter by Status
    if (statusFilter != 'Todos') {
      query = query.eq('status', statusFilter);
    }

    // 2. Filter by Date Range
    if (dateRange != null) {
      final startIso = dateRange.start.toIso8601String();
      final endIso =
          dateRange.end.add(const Duration(days: 1)).toIso8601String();
      query = query.gte('created_at', startIso).lt('created_at', endIso);
    }

    // 3. Filter by Search Text
    if (searchText.trim().isNotEmpty) {
      final txt = '%${searchText.trim()}%';
      query = query.or(
        'supplier_name.ilike.$txt,document_number.ilike.$txt,notes.ilike.$txt',
      );
    }

    // Sort and Paginate
    final finalQuery = query
        .order('created_at', ascending: false)
        .range(start, end)
        .count(CountOption.exact);

    final response = await finalQuery;
    final List<PurchaseOrderModel> dataList =
        (response.data as List)
            .map(
              (e) => PurchaseOrderModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();

    return {'data': dataList, 'count': response.count};
  }

  /// Fetches the items for a specific purchase order.
  Future<List<PurchaseOrderItemModel>> fetchOrderItems(String poId) async {
    final response = await _supabase
        .from('purchase_order_items')
        .select('''
          product_id, variant_id,
          quantity_ordered, quantity_received, unit_cost,
          batch_number, expiry_date,
          products!inner(
            name, uses_batches,
            product_images(image_url, is_main, display_order, variant_id)
          ),
          product_variants!inner(
            sku,
            variant_attribute_values(attribute_values(id, value, attributes(id, name))),
            product_images(image_url, is_main, display_order)
          )
        ''')
        .eq('purchase_order_id', poId);

    return (response as List).map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variant = r['product_variants'] as Map<String, dynamic>?;
      final variantId = r['variant_id'] as String;

      // ── Parse Attributes ──
      final List<VariantAttributeValueModel> parsedAttrs = [];
      if (variant != null && variant['variant_attribute_values'] is List) {
        for (final vav in variant['variant_attribute_values'] as List) {
          try {
            parsedAttrs.add(
              VariantAttributeValueModel.fromJson(
                Map<String, dynamic>.from(vav as Map),
              ),
            );
          } catch (_) {
            // Ignorar malformados
          }
        }
      }
      final attrsText =
          parsedAttrs.isNotEmpty
              ? parsedAttrs
                  .map(
                    (a) =>
                        a.attributeName.isNotEmpty
                            ? '${a.attributeName}: ${a.value}'
                            : a.value,
                  )
                  .join(' · ')
              : 'Única';

      // ── Fetch Image ──
      String? imageUrl;
      // 1) Variante image
      final variantImages = variant?['product_images'] as List?;
      if (variantImages != null && variantImages.isNotEmpty) {
        final main = variantImages.firstWhere(
          (img) => img['is_main'] == true,
          orElse: () => variantImages.first,
        );
        imageUrl = main['image_url'] as String?;
      }

      // 2) Producto fallback image
      if (imageUrl == null) {
        final productImages = prod?['product_images'] as List?;
        if (productImages != null && productImages.isNotEmpty) {
          final forVariant =
              productImages
                  .where((img) => img['variant_id'] == variantId)
                  .toList();
          if (forVariant.isNotEmpty) {
            final main = forVariant.firstWhere(
              (img) => img['is_main'] == true,
              orElse: () => forVariant.first,
            );
            imageUrl = main['image_url'] as String?;
          } else {
            final generic =
                productImages
                    .where((img) => img['variant_id'] == null)
                    .toList();
            final pool = generic.isNotEmpty ? generic : productImages;
            final main = pool.firstWhere(
              (img) => img['is_main'] == true,
              orElse: () => pool.first,
            );
            imageUrl = main['image_url'] as String?;
          }
        }
      }

      return PurchaseOrderItemModel(
        productId: r['product_id'] as String,
        variantId: variantId,
        productName: prod?['name'] as String?,
        variantAttrs: attrsText,
        sku: variant?['sku'] as String?,
        quantityOrdered: (r['quantity_ordered'] as num).toDouble(),
        quantityReceived: (r['quantity_received'] as num?)?.toDouble() ?? 0,
        unitCost: (r['unit_cost'] as num).toDouble(),
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
        expiryDate:
            r['expiry_date'] != null
                ? DateTime.tryParse(r['expiry_date'] as String)
                : null,
        usesBatches: prod?['uses_batches'] as bool? ?? false,
        imageUrl: imageUrl,
      );
    }).toList();
  }

  /// Updates the status of a purchase order.
  Future<void> updateOrderStatus(String poId, String status) async {
    await _supabase
        .from('purchase_orders')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', poId);
  }

  /// Creates a new Purchase Order and its items, handling financial logic too.
  Future<void> createPurchaseOrder({
    required String supplierId,
    required String supplierName,
    required String warehouseId,
    required List<dynamic>
    items, // Expected to be EntryItemUI from UI layer, we will use dynamic to avoid circular import, or just pass primitives
    required double totalAmount,
    required String paymentMode,
    required String paymentStatus,
    required String? accountId,
    required String? activeShiftId,
    required DateTime? dueDate,
    required DateTime? documentDate,
    required String documentType,
    required String? documentNumber,
    required String? notes,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    String? profileId;
    if (currentUser != null) {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', currentUser.id)
              .maybeSingle();
      profileId = profile?['id'] as String?;
    }

    // 1. Insert Purchase Order
    final poResp =
        await _supabase
            .from('purchase_orders')
            .insert({
              'supplier_id': supplierId,
              'supplier_name': supplierName,
              'warehouse_id': warehouseId,
              'status': 'SENT',
              'total_amount': totalAmount,
              'payment_method': paymentMode,
              'payment_status': paymentStatus,
              'amount_paid': paymentStatus == 'PAID' ? totalAmount : 0,
              'due_date': dueDate?.toIso8601String().split('T').first,
              'document_type': documentType,
              'document_number': documentNumber,
              'document_date': documentDate?.toIso8601String().split('T').first,
              'notes': notes,
              'created_by': profileId,
            })
            .select('id')
            .single();

    final poId = poResp['id'] as String;

    // 2. Insert Items
    for (final item in items) {
      await _supabase.from('purchase_order_items').insert({
        'purchase_order_id': poId,
        'product_id': item.product.id,
        'variant_id': item.variant.id,
        'quantity_ordered': item.quantity,
        'unit_cost': item.unitCost,
        'net_cost': item.subtotal,
        'batch_number': item.batchNumber,
        'expiry_date': item.expiryDate?.toIso8601String().split('T').first,
      });
    }

    // 3. Finanzas: Pago Adelantado
    if (paymentStatus == 'PAID' && accountId != null) {
      final accountDataResp =
          await _supabase
              .from('financial_accounts')
              .select('balance')
              .eq('id', accountId)
              .single();

      final currentBalance = (accountDataResp['balance'] as num).toDouble();

      await _supabase.from('account_movements').insert({
        'account_id': accountId,
        'movement_type': 'EXPENSE',
        'amount': totalAmount,
        'description': 'Pago adelantado Orden de Compra · $supplierName',
        'reference_type': 'purchase_order',
        'reference_id': poId,
        'created_by': profileId,
        'shift_id': activeShiftId,
      });

      await _supabase
          .from('financial_accounts')
          .update({'balance': currentBalance - totalAmount})
          .eq('id', accountId);
    }
    // 4. Finanzas: Compra a Crédito
    else if (paymentMode == 'CREDITO') {
      final creditResp =
          await _supabase
              .from('supplier_credits')
              .select('id, current_debt')
              .eq('supplier_id', supplierId)
              .single();
      final supplierCreditId = creditResp['id'] as String;

      await _supabase
          .from('supplier_credits')
          .update({
            'current_debt':
                (creditResp['current_debt'] as num).toDouble() + totalAmount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', supplierCreditId);

      await _supabase.from('supplier_credit_movements').insert({
        'supplier_credit_id': supplierCreditId,
        'purchase_order_id': poId,
        'movement_type': 'CHARGE',
        'amount': totalAmount,
        'payment_method': 'CREDITO',
        'due_date': dueDate?.toIso8601String().split('T').first,
        'notes': 'Orden de Compra en Tránsito',
        'created_by': profileId,
      });
    }
  }

  /// Busca productos de manera asíncrona en el servidor.
  Future<List<Map<String, dynamic>>> searchProducts(String queryText) async {
    final response = await _supabase
        .from('products')
        .select('*, product_images(*)')
        .eq('is_active', true)
        .eq('stock_control', true)
        .neq('product_type', 'service')
        .ilike('name', '%$queryText%')
        .limit(20);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Obtiene variantes dado un product_id.
  Future<List<Map<String, dynamic>>> getProductVariants(
    String productId,
  ) async {
    final response = await _supabase
        .from('product_variants')
        .select(
          '*, product_images(*), variant_attribute_values(attribute_values(value, attributes(name)))',
        )
        .eq('product_id', productId)
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response as List);
  }
}
