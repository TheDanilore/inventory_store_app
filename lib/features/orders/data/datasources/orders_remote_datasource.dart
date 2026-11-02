import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';

@lazySingleton
class OrdersRemoteDataSource {
  final SupabaseClient _supabase;

  OrdersRemoteDataSource({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // Multiplexación para Realtime compartido
  StreamController<int>? _pendingOrdersCountController;
  RealtimeChannel? _pendingOrdersCountChannel;
  Timer? _pendingOrdersCountDebounce;
  int _pendingOrdersCountListeners = 0;

  Future<List<OrderModel>> getCustomerOrders(
    String profileId, {
    int limit = 10,
    DateTime? lastCreatedAt,
  }) async {
    var query = _supabase
        .from('orders')
        .select('''
      id, customer_id, customer_name, total_amount,
      discount_amount, payment_method, payment_status, amount_paid,
      status, due_date, points_used, points_earned, created_at,
      warehouse_id,
      document_type, document_series, document_number, document_date,
      tax_amount, subtotal_amount, customer_document_type,
      customer_document_number, customer_address, payment_reference,
      currency_code, exchange_rate, total_amount_base,
      subtotal_amount_base, tax_amount_base,
      warehouses!orders_store_id_fkey ( id, name )
    ''')
        .eq('customer_id', profileId);

    if (lastCreatedAt != null) {
      query = query.lt('created_at', lastCreatedAt.toUtc().toIso8601String());
    }

    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List).map((json) => OrderModel.fromJson(json)).toList();
  }

  Future<List<OrderModel>> getPendingOrdersByCustomer(String customerId) async {
    final data = await _supabase
        .from('orders')
        .select('id, total_amount, amount_paid, payment_status, created_at')
        .eq('customer_id', customerId)
        .eq('status', 'COMPLETED')
        .inFilter('payment_status', ['PENDING', 'PARTIAL'])
        .order('created_at', ascending: true);

    return (data as List).map((json) => OrderModel.fromJson(json)).toList();
  }

  Future<({List<OrderModel> orders, int total})> getFilteredOrders({
    String? customerIdFilter,
    required String statusFilter,
    required String paymentStatusFilter,
    String? warehouseFilter,
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
    required int limit,
    required int offset,
  }) async {
    var query = _supabase.from('orders').select('''
      id,
      customer_id,
      customer_name,
      total_amount,
      total_profit,
      discount_amount,
      payment_method,
      payment_status,
      amount_paid,
      status,
      due_date,
      points_used,
      points_earned,
      created_at,
      warehouse_id,
      created_by,
      document_type,
      document_series,
      document_number,
      document_date,
      tax_amount,
      subtotal_amount,
      customer_document_type,
      customer_document_number,
      customer_address,
      payment_reference,
      currency_code,
      exchange_rate,
      total_amount_base,
      subtotal_amount_base,
      tax_amount_base,
      profiles!orders_customer_id_fkey ( id, full_name, phone ),
      warehouses!orders_store_id_fkey ( id, name )
    ''');

    if (statusFilter != 'ALL') query = query.eq('status', statusFilter);
    if (paymentStatusFilter != 'ALL') {
      if (paymentStatusFilter == 'CREDIT') {
        query = query.or(
          'payment_method.ilike.%crédito%,payment_method.ilike.%credito%',
        );
      } else {
        query = query.eq('payment_status', paymentStatusFilter);
      }
    }

    if (warehouseFilter != null &&
        warehouseFilter != 'ALL' &&
        warehouseFilter != 'Todos' &&
        warehouseFilter != 'TODOS') {
      query = query.eq('warehouses.name', warehouseFilter);
    }

    if (customerIdFilter != null) {
      query = query.eq('customer_id', customerIdFilter);
    }

    if (startDate != null && endDate != null) {
      final start = startDate.toIso8601String();
      final end =
          endDate
              .add(const Duration(hours: 23, minutes: 59, seconds: 59))
              .toIso8601String();
      query = query.gte('created_at', start).lte('created_at', end);
    }

    final clean = searchQuery.replaceAll('#', '').trim();
    if (clean.isNotEmpty) {
      final txt = '%$clean%';
      final isFullUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(clean);
      final isShortHex = RegExp(r'^[0-9a-fA-F]{4,8}$').hasMatch(clean);

      if (isFullUuid) {
        query = query.or('id.eq.$clean,customer_name.ilike.$txt');
      } else if (isShortHex) {
        final prefix = clean.toLowerCase();
        final padZeros = '0' * (8 - prefix.length);
        final padFs = 'f' * (8 - prefix.length);
        final minUuid = '$prefix$padZeros-0000-0000-0000-000000000000';
        final maxUuid = '$prefix$padFs-ffff-ffff-ffff-ffffffffffff';
        query = query.or(
          'and(id.gte.$minUuid,id.lte.$maxUuid),customer_name.ilike.$txt',
        );
      } else {
        query = query.or('customer_name.ilike.$txt');
      }
    }

    final startRow = offset;
    final endRow = startRow + limit - 1;

    final response = await query
        .order('created_at', ascending: false)
        .range(startRow, endRow)
        .count(CountOption.exact);

    final rawData = response.data as List<dynamic>;
    final totalRecords = response.count;
    final orders = rawData.map((e) => OrderModel.fromJson(e)).toList();

    return (orders: orders, total: totalRecords);
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    final data =
        await _supabase
            .from('orders')
            .select('''
      id,
      customer_id,
      customer_name,
      total_amount,
      total_profit,
      discount_amount,
      payment_method,
      payment_status,
      amount_paid,
      status,
      due_date,
      points_used,
      points_earned,
      created_at,
      warehouse_id,
      created_by,
      document_type,
      document_series,
      document_number,
      document_date,
      tax_amount,
      subtotal_amount,
      customer_document_type,
      customer_document_number,
      customer_address,
      payment_reference,
      currency_code,
      exchange_rate,
      total_amount_base,
      subtotal_amount_base,
      tax_amount_base,
      profiles!orders_customer_id_fkey ( id, full_name, phone ),
      warehouses!orders_store_id_fkey ( id, name )
    ''')
            .eq('id', orderId)
            .maybeSingle();

    if (data == null) return null;
    return OrderModel.fromJson(data);
  }

  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    final data = await _supabase
        .from('order_items')
        .select('''
      id, order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit, created_at,
      products ( id, name, product_images (image_url, is_main) ),
      product_variants ( id, sku, product_images (image_url, is_main), variant_attribute_values(attribute_values(value, attributes(name))) )
    ''')
        .eq('order_id', orderId);

    return (data as List).map((json) => OrderItemModel.fromJson(json)).toList();
  }

  Future<String?> resolveCurrentProfileId(String? passedProfileId) async {
    if (passedProfileId != null && passedProfileId.trim().isNotEmpty) {
      return passedProfileId.trim();
    }
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null) return null;

    try {
      final res =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      return res?['id'] as String?;
    } catch (e) {
      LoggerService.w(
        'No se pudo resolver profile_id desde auth_user_id: $e',
        tag: 'OrdersRemoteDataSource',
      );
      return null;
    }
  }

  Future<void> updateOrderStatusDirect({
    required String orderId,
    required String newStatus,
    required String? effectiveProfileId,
  }) async {
    await _supabase
        .from('orders')
        .update({
          'status': newStatus,
          if (effectiveProfileId != null) 'updated_by': effectiveProfileId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);
  }

  Future<void> completeOrderRpc(Map<String, dynamic> payload) async {
    await _supabase.rpc('rpc_complete_order', params: {'payload': payload});
  }

  Future<void> cancelOrderRpc(Map<String, dynamic> payload) async {
    await _supabase.rpc('rpc_cancel_order', params: {'payload': payload});
  }

  Future<void> saveOrderDraftDirect({
    required String orderId,
    required Map<String, dynamic> orderUpdate,
    required List<Map<String, dynamic>> upsertItems,
  }) async {
    await _supabase.from('orders').update(orderUpdate).eq('id', orderId);
    if (upsertItems.isNotEmpty) {
      await _supabase.from('order_items').upsert(upsertItems);
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrderItemsForPdf(
    String orderId,
  ) async {
    final resp = await _supabase
        .from('order_items')
        .select('''
      id, order_id, product_id, variant_id, quantity, unit_cost,
      applied_price, net_profit, created_at,
      products!inner ( name ),
      product_variants (
        sku,
        variant_attribute_values(attribute_values(value, attributes(name)))
      )
    ''')
        .eq('order_id', orderId);

    return List<Map<String, dynamic>>.from(resp);
  }

  Future<List<Map<String, dynamic>>> getFinancialAccounts() async {
    final response = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance')
        .eq('is_active', true)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getProfileById(String profileId) async {
    final response =
        await _supabase
            .from('profiles')
            .select('id, full_name, phone, wallet_balance')
            .eq('id', profileId)
            .maybeSingle();
    return response;
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final response = await _supabase
        .from('profiles')
        .select('id, full_name, phone, document_number')
        .or(
          'full_name.ilike.%$query%,phone.ilike.%$query%,document_number.ilike.%$query%',
        )
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<String?> checkActiveCashShift() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final userShift =
          await _supabase
              .from('cash_shifts')
              .select('id')
              .eq('status', 'OPEN')
              .eq('opened_by', user.id)
              .order('opened_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (userShift != null && userShift['id'] != null) {
        return userShift['id'] as String;
      }
    }

    final anyShift =
        await _supabase
            .from('cash_shifts')
            .select('id')
            .eq('status', 'OPEN')
            .order('opened_at', ascending: false)
            .limit(1)
            .maybeSingle();

    if (anyShift != null && anyShift['id'] != null) {
      return anyShift['id'] as String;
    }
    return null;
  }

  Future<dynamic> registerCreditPaymentRpc(Map<String, dynamic> params) async {
    return await _supabase.rpc('register_credit_payment_rpc', params: params);
  }

  Future<List<BatchAssignmentModel>> fetchBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    final resp = await _supabase
        .from('warehouse_stock_batches')
        .select('id, batch_number, expiry_date, available_quantity')
        .eq('variant_id', variantId)
        .eq('warehouse_id', warehouseId)
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false);

    return (resp as List).map((b) {
      return BatchAssignmentModel(
        batchId: b['id'] as String,
        batchNumber: b['batch_number'] as String,
        expiryDate:
            b['expiry_date'] != null
                ? DateTime.tryParse(b['expiry_date'] as String)
                : null,
        available: (b['available_quantity'] as num).toInt(),
        assigned: 0,
      );
    }).toList();
  }

  Future<
    ({
      List<CartItemEntity> validItems,
      List<String> outOfStock,
      List<String> priceChanged,
    })
  >
  validateReorderItems(List<OrderItemEntity> items) async {
    final productIds =
        items.map((e) => e.productId).whereType<String>().toSet().toList();
    if (productIds.isEmpty) {
      return (
        validItems: <CartItemEntity>[],
        outOfStock: <String>[],
        priceChanged: <String>[],
      );
    }

    final productsData = await _supabase
        .from('products')
        .select(
          'id, name, is_active, uses_batches, product_variants(id, sale_price, unit_cost, is_active), warehouse_stock_batches(product_id, variant_id, available_quantity)',
        )
        .inFilter('id', productIds);

    final productsMap = {for (final p in productsData) p['id'] as String: p};

    final validItems = <CartItemEntity>[];
    final outOfStock = <String>[];
    final priceChanged = <String>[];

    for (final item in items) {
      if (item.productId == null || !productsMap.containsKey(item.productId)) {
        outOfStock.add(item.productName ?? 'Producto no disponible');
        continue;
      }

      final pData = productsMap[item.productId!];
      if (pData == null || pData['is_active'] == false) {
        outOfStock.add(item.productName ?? 'Producto descontinuado');
        continue;
      }

      final usesBatches = pData['uses_batches'] == true;
      double currentPrice = item.appliedPrice;
      double currentCost = item.unitCost;
      bool isVariantActive = true;

      final variants = pData['product_variants'] as List<dynamic>? ?? [];
      if (item.variantId != null && variants.isNotEmpty) {
        final variant = variants.cast<Map<String, dynamic>>().firstWhere(
          (v) => v['id'] == item.variantId,
          orElse: () => <String, dynamic>{},
        );
        if (variant.isNotEmpty) {
          if (variant['is_active'] == false) {
            isVariantActive = false;
          } else {
            currentPrice =
                (variant['sale_price'] as num?)?.toDouble() ?? currentPrice;
            currentCost =
                (variant['unit_cost'] as num?)?.toDouble() ?? currentCost;
          }
        } else {
          isVariantActive = false;
        }
      }

      if (!isVariantActive) {
        outOfStock.add(
          item.variantDisplayName ??
              item.productName ??
              'Variante no disponible',
        );
        continue;
      }

      final batches = pData['warehouse_stock_batches'] as List<dynamic>? ?? [];
      int totalAvailableStock = 0;
      for (final b in batches) {
        final bMap = b as Map<String, dynamic>;
        if (item.variantId != null) {
          if (bMap['variant_id'] == item.variantId) {
            totalAvailableStock +=
                (bMap['available_quantity'] as num?)?.toInt() ?? 0;
          }
        } else {
          if (bMap['variant_id'] == null || bMap['variant_id'] == '') {
            totalAvailableStock +=
                (bMap['available_quantity'] as num?)?.toInt() ?? 0;
          }
        }
      }

      if (totalAvailableStock <= 0) {
        outOfStock.add(
          item.variantDisplayName ?? item.productName ?? 'Agotado',
        );
        continue;
      }

      if ((currentPrice - item.appliedPrice).abs() > 0.01) {
        priceChanged.add(
          item.variantDisplayName ?? item.productName ?? 'Artículo actualizado',
        );
      }

      final qtyToTake =
          item.quantity > totalAvailableStock
              ? totalAvailableStock
              : item.quantity;

      validItems.add(
        CartItemEntity(
          productId: item.productId!,
          productName:
              pData['name'] as String? ?? item.productName ?? 'Producto',
          cartKey: item.variantId ?? item.productId ?? item.id,
          quantity: qtyToTake,
          unitPrice: currentPrice,
          unitCost: currentCost,
          availableStock: totalAvailableStock,
          usesBatches: usesBatches,
          variantId: item.variantId,
          variantLabel: item.variantDisplayName,
          imageUrl: item.displayImageUrl,
          sku: item.sku,
          isSelected: true,
        ),
      );
    }

    return (
      validItems: validItems,
      outOfStock: outOfStock,
      priceChanged: priceChanged,
    );
  }

  Stream<int> watchPendingOrdersCount() {
    if (_pendingOrdersCountController != null &&
        !_pendingOrdersCountController!.isClosed) {
      return _pendingOrdersCountController!.stream;
    }

    final controller = StreamController<int>.broadcast();
    _pendingOrdersCountController = controller;

    Future<void> fetchCount() async {
      try {
        final response = await _supabase
            .from('orders')
            .select('id')
            .eq('status', 'PENDING')
            .count(CountOption.exact);

        if (!controller.isClosed) {
          controller.add(response.count);
        }
      } catch (e, st) {
        LoggerService.e(
          'Error fetching pending orders count in datasource',
          tag: 'OrdersRemoteDataSource',
          error: e,
          stackTrace: st,
        );
      }
    }

    controller.onListen = () async {
      _pendingOrdersCountListeners++;
      if (_pendingOrdersCountChannel != null) {
        await fetchCount();
        return;
      }
      await fetchCount();
      _pendingOrdersCountChannel = _supabase
          .channel('public:orders:pending_count')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              final newStatus = payload.newRecord['status'];
              final oldStatus = payload.oldRecord['status'];
              final isRelevant =
                  newStatus == 'PENDING' ||
                  oldStatus == 'PENDING' ||
                  payload.eventType == PostgresChangeEvent.insert ||
                  payload.eventType == PostgresChangeEvent.delete;

              if (isRelevant) {
                _pendingOrdersCountDebounce?.cancel();
                _pendingOrdersCountDebounce = Timer(
                  const Duration(milliseconds: 2000),
                  () {
                    fetchCount();
                  },
                );
              }
            },
          );
      _pendingOrdersCountChannel!.subscribe();
    };

    controller.onCancel = () async {
      _pendingOrdersCountListeners--;
      if (_pendingOrdersCountListeners <= 0) {
        _pendingOrdersCountListeners = 0;
        _pendingOrdersCountDebounce?.cancel();
        _pendingOrdersCountDebounce = null;
        await _pendingOrdersCountChannel?.unsubscribe();
        _pendingOrdersCountChannel = null;
        await controller.close();
        _pendingOrdersCountController = null;
      }
    };

    return controller.stream;
  }
}
