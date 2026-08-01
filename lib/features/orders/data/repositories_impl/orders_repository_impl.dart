import 'dart:async' show StreamController;

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: OrdersRepository)
class OrdersRepositoryImpl implements OrdersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(
    String profileId, {
    int limit = 10,
    DateTime? lastCreatedAt,
  }) async {
    try {
      var query = _supabase
          .from('orders')
          .select('''
            id, customer_id, customer_name, total_amount, total_profit,
            discount_amount, payment_method, payment_status, amount_paid,
            status, due_date, points_used, points_earned, created_at,
            warehouse_id, created_by,
            profiles!orders_customer_id_fkey ( id, full_name, phone ),
            warehouses!orders_store_id_fkey ( id, name )
          ''')
          .eq('customer_id', profileId);

      if (lastCreatedAt != null) {
        // Keyset pagination para infinito scroll estable
        query = query.lt('created_at', lastCreatedAt.toUtc().toIso8601String());
      }

      final data = await query.order('created_at', ascending: false).limit(limit);

      final orders = data.map((json) => OrderModel.fromJson(json)).toList();
      return Right(orders);
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en getCustomerOrders: $e\n$st');
      return Left(ServerFailure(message: 'Error fetching orders: $e'));
    }
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getPendingOrdersByCustomer(String customerId) async {
    try {
      final data = await _supabase
          .from('orders')
          .select('id, total_amount, amount_paid, payment_status, created_at')
          .eq('customer_id', customerId)
          .inFilter('payment_status', ['PENDING', 'PARTIAL'])
          .order('created_at', ascending: true);

      // We only need basic fields for pending orders in the UI
      final orders = data.map((json) => OrderModel.fromJson(json)).toList();
      return Right(orders);
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en getPendingOrdersByCustomer: $e\n$st');
      return Left(ServerFailure(message: 'Error fetching pending orders: $e'));
    }
  }

  @override
  Future<Either<Failure, ({List<OrderEntity> orders, int total})>>
  getFilteredOrders({
    String? customerIdFilter,
    required String statusFilter,
    required String paymentStatusFilter,
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
    required int limit,
    required int offset,
  }) async {
    try {
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
        profiles!orders_customer_id_fkey ( id, full_name, phone ),
        warehouses!orders_store_id_fkey ( id, name )
      ''');

      if (statusFilter != 'ALL') query = query.eq('status', statusFilter);
      if (paymentStatusFilter != 'ALL') {
        query = query.eq('payment_status', paymentStatusFilter);
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

      final queryText = searchQuery.trim().toLowerCase();
      if (queryText.isNotEmpty) {
        final profilesResp = await _supabase
            .from('profiles')
            .select('id')
            .ilike('full_name', '%$queryText%');
        final matchingProfileIds =
            (profilesResp as List).map((e) => e['id']).toList();

        if (matchingProfileIds.isNotEmpty) {
          final idsString = matchingProfileIds.join(',');
          query = query.or(
            'customer_name.ilike.%$queryText%,id.ilike.%$queryText%,customer_id.in.($idsString)',
          );
        } else {
          query = query.or(
            'customer_name.ilike.%$queryText%,id.ilike.%$queryText%',
          );
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

      return Right((orders: orders, total: totalRecords));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        return const Left(ServerFailure(message: 'Sin conexión a internet.'));
      }
      return Left(ServerFailure(message: 'Error fetching orders: $e'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> getOrderById(String orderId) async {
    try {
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
        profiles!orders_customer_id_fkey ( id, full_name, phone ),
        warehouses!orders_store_id_fkey ( id, name )
      ''')
              .eq('id', orderId)
              .maybeSingle();

      if (data == null) {
        debugPrint(
          '🔴 [OrdersRepo] getOrderById data == null para id: $orderId',
        );
        return const Left(ServerFailure(message: 'Pedido no encontrado.'));
      }
      return Right(OrderModel.fromJson(data));
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en getOrderById: $e\n$st');
      return Left(ServerFailure(message: 'Error fetching order: $e'));
    }
  }

  @override
  Future<Either<Failure, List<OrderItemEntity>>> getOrderItems(
    String orderId,
  ) async {
    try {
      final data = await _supabase
          .from('order_items')
          .select('''
        *,
        products ( id, name, product_images (image_url, is_main) ),
        product_variants ( id, sku, product_images (image_url, is_main), variant_attribute_values(attribute_values(value, attributes(name))) )
      ''')
          .eq('order_id', orderId);

      final items = data.map((json) => OrderItemModel.fromJson(json)).toList();
      return Right(items);
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en getOrderItems: $e\n$st');
      return Left(ServerFailure(message: 'Error fetching order items: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateOrderStatus({
    required OrderEntity order,
    required String newStatus,
    required String? currentProfileId,
  }) async {
    try {
      if (newStatus == 'COMPLETED' && order.status == 'PENDING') {
        // Obtenemos los items internamente, evitando Data Egress al BLoC
        final itemsResult = await getOrderItems(order.id);
        
        return itemsResult.fold(
          (failure) => Left(failure),
          (items) async {
            return await saveOrderChanges(
              orderId: order.id,
              originalStatus: order.status,
              newStatus: newStatus,
              paymentMethod: order.paymentMethod,
              selectedCustomerId: order.customerId,
              customerNameToSave: order.customerName,
              items: items,
              pointsUsed: order.pointsUsed,
              pointsEarned: order.pointsEarned,
              totalAmount: order.totalAmount,
              totalProfit: order.totalProfit,
              batchOverrides: {},
              currentProfileId: currentProfileId,
            );
          },
        );
      } else if (newStatus == 'CANCELLED' || newStatus == 'RETURNED') {
        return await cancelOrder(
          orderId: order.id,
          customerId: order.customerId,
          currentProfileId: currentProfileId,
        );
      } else {
        // Actualización simple de estado en BD
        await _supabase
            .from('orders')
            .update({'status': newStatus})
            .eq('id', order.id);
        return const Right(null);
      }
    } on PostgrestException catch (e, st) {
      debugPrint('🔴 [OrdersRepo] PostgrestException en updateOrderStatus: $e\n$st');
      return Left(ServerFailure(message: 'Error de base de datos al actualizar el estado.'));
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error inesperado en updateOrderStatus: $e\n$st');
      return Left(ServerFailure(message: 'Error inesperado al actualizar el estado.'));
    }
  }


  // ─── GUARDAR CAMBIOS ────────────────────────────────────────────────────────

  /// Guarda todos los cambios de un pedido en edición.
  ///
  /// Maneja los 3 escenarios posibles:
  ///   - PENDING → COMPLETED (activar borrador, descontar stock, registrar pago)
  ///   - COMPLETED → CANCELLED (revertir stock, pago, puntos de fidelidad)
  ///   - Actualización simple de datos (cliente, método de pago, etc.)
  @override
  Future<Either<Failure, void>> saveOrderChanges({
    required String orderId,
    required String originalStatus,
    required String newStatus,
    required String paymentMethod,
    required String? selectedCustomerId,
    required String? customerNameToSave,
    required List<OrderItemEntity> items,
    required int pointsUsed,
    required int pointsEarned,
    required double totalAmount,
    required double totalProfit,
    required Map<String, List<BatchAssignmentModel>> batchOverrides,
    required String? currentProfileId,
    String? notesOverride,
  }) async {
    try {
      final wasCompleted = originalStatus.toUpperCase() == 'COMPLETED';
      final isNowCompleted = newStatus.toUpperCase() == 'COMPLETED';
      final isNowCancelled = newStatus.toUpperCase() == 'CANCELLED';

      // ─── BLOQUEO: método de pago vacío al completar ───────────────────────
      if (isNowCompleted &&
          (paymentMethod == 'POR ACORDAR' || paymentMethod.trim().isEmpty)) {
        return const Left(
          ServerFailure(message: '__PAYMENT_METHOD_REQUIRED__'),
        );
      }

      // ─── PREPARAR PAYLOAD PARA RPC ───────────────────────────────────────
      final payload = {
        'order_id': orderId,
        'payment_method': paymentMethod,
        'selected_customer_id': selectedCustomerId,
        'customer_name_to_save': customerNameToSave,
        'points_used': pointsUsed,
        'points_earned': pointsEarned,
        'total_amount': totalAmount,
        'total_profit': totalProfit,
        'current_profile_id': currentProfileId,
        'items': items.map((i) => {
          'id': i.id,
          'variant_id': i.variantId,
          'quantity': i.quantity,
          'unit_cost': i.unitCost,
          'applied_price': i.appliedPrice,
        }).toList(),
        'batch_overrides': batchOverrides.map((k, v) => MapEntry(k, v.map((b) => {
          'batch_id': b.batchId,
          'assigned': b.assigned,
        }).toList())),
      };

      // ─── ESCENARIO 1: PENDING → COMPLETED (RPC) ────────────────────────
      if (!wasCompleted && isNowCompleted) {
        await _supabase.rpc('rpc_complete_order', params: {'payload': payload});
        return const Right(null);
      } 
      // ─── ESCENARIO 2: COMPLETED → CANCELLED (RPC) ───────────────────────
      else if (wasCompleted && isNowCancelled) {
        return cancelOrder(
          orderId: orderId,
          customerId: selectedCustomerId,
          currentProfileId: currentProfileId,
          notesOverride: notesOverride,
        );
      }

      // ─── ESCENARIO 3: SIMPLE SAVE (Borrador) ────────────────────────────
      // Lógica de puntos (crédito no genera en borrador)
      int finalPointsUsed = paymentMethod == 'CRÉDITO' ? 0 : pointsUsed;
      int finalPointsEarned = paymentMethod == 'CRÉDITO' ? 0 : pointsEarned;
      String paymentStatus = paymentMethod == 'CRÉDITO' ? 'PENDING' : 'PAID';
      double amountPaid = paymentMethod == 'CRÉDITO' ? 0 : totalAmount;

      await _supabase
          .from('orders')
          .update({
            'customer_id': selectedCustomerId,
            'customer_name': customerNameToSave ?? '',
            'status': newStatus,
            'payment_method': paymentMethod,
            'payment_status': paymentStatus,
            'amount_paid': amountPaid,
            'total_amount': totalAmount,
            'total_profit': totalProfit,
            'points_used': finalPointsUsed,
            'points_earned': finalPointsEarned,
            'updated_by': currentProfileId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId);

      await Future.wait(
        items.map(
          (item) => _supabase
              .from('order_items')
              .update({
                'quantity': item.quantity,
                'unit_cost': item.unitCost,
                'net_profit':
                    (item.appliedPrice - item.unitCost) * item.quantity,
              })
              .eq('id', item.id),
        ),
      );

      return const Right(null);
    } catch (e) {
      debugPrint('[OrderDetailService] saveOrderChanges error: $e');
      return Left(ServerFailure(message: 'Error al guardar: $e'));
    }
  }

  // ─── DEVOLUCIÓN (widget Registrar Devolución) ──────────────────────────────

  @override
  Future<Either<Failure, void>> processReturn({
    required String orderId,
    required List<OrderItemEntity> items,
    required String? currentProfileId,
    String? notesOverride,
  }) async {
    try {
      await cancelOrder(
        orderId: orderId,
        customerId: null, // Resolves internally via RPC
        currentProfileId: currentProfileId,
        notesOverride:
            notesOverride ?? 'Reembolso por devolución · Pedido #$orderId',
      );
      return const Right(null);
    } catch (e) {
      debugPrint('[OrderDetailService] processReturn error: $e');
      return Left(ServerFailure(message: 'Error al registrar devolución: $e'));
    }
  }

  /// Resuelve el profileId del usuario autenticado actual.

  /// Obtiene un pedido por su ID con todos los detalles necesarios para OrderModel

  /// Completa un pedido PENDING:
  /// - Descuenta stock en lotes (FIFO).
  /// - Actualiza deuda de crédito o registra ingreso en cuenta financiera.
  /// - Actualiza el estado del pedido.
  /// - Otorga/descuenta monedas del wallet.
  ///
  /// Lanza [Exception] si hay problemas (stock insuficiente, crédito sin límite, etc.).
  Future<void> completeOrder({
    required Map<String, dynamic> order,
    required String orderId,
    required String paymentMethod,
    required double totalAmount,
    required String? customerId,
    required int pointsUsed,
    required int pointsEarned,
    required String? currentProfileId,
  }) async {
    final warehouseId = order['warehouse_id'] as String?;
    if (warehouseId == null) {
      throw Exception('El pedido no tiene almacén asignado.');
    }

    final isCredito = paymentMethod == 'CRÉDITO';

    // ── 1. Validar crédito si aplica ─────────────────────────────────────
    if (isCredito) {
      if (customerId == null) {
        throw Exception('No hay cliente asignado para crédito.');
      }
      final creditInfo =
          await _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', customerId)
              .maybeSingle();

      if (creditInfo == null || creditInfo['is_active'] != true) {
        throw Exception('El cliente no tiene línea de crédito activa.');
      }
      final available =
          (creditInfo['credit_limit'] as num).toDouble() -
          (creditInfo['current_debt'] as num).toDouble();
      if (available < totalAmount) {
        throw Exception(
          'Crédito insuficiente. Disponible: S/ ${available.toStringAsFixed(2)}',
        );
      }
    }

    // ── 2. Descontar stock en lotes (FIFO) ───────────────────────────────
    final itemsResp = await _supabase
        .from('order_items')
        .select('product_id, variant_id, quantity, products(name)')
        .eq('order_id', orderId);

    final items = List<Map<String, dynamic>>.from(itemsResp);
    final List<Map<String, dynamic>> batchesToUpdate = [];
    final List<Map<String, dynamic>> movementsToInsert = [];

    for (final item in items) {
      final variantId = item['variant_id'] as String?;
      if (variantId == null) continue;
      final qtyNeeded = item['quantity'] as int;
      final productName =
          (item['products'] as Map<String, dynamic>?)?['name'] as String? ?? '';

      final batchesResp = await _supabase
          .from('warehouse_stock_batches')
          .select('id, available_quantity')
          .eq('warehouse_id', warehouseId)
          .eq('variant_id', variantId)
          .order('created_at', ascending: true);

      final batches = List<Map<String, dynamic>>.from(batchesResp);
      final currentStock = batches.fold<int>(
        0,
        (sum, b) => sum + ((b['available_quantity'] as num?)?.toInt() ?? 0),
      );

      if (currentStock < qtyNeeded) {
        throw Exception(
          'Stock insuficiente para "$productName". Disponible: $currentStock, requerido: $qtyNeeded.',
        );
      }

      int remaining = qtyNeeded;
      for (final batch in batches) {
        if (remaining <= 0) break;
        final int batchStock =
            (batch['available_quantity'] as num?)?.toInt() ?? 0;
        if (batchStock <= 0) continue;
        final int deduct = batchStock >= remaining ? remaining : batchStock;
        final int newStock = batchStock - deduct;

        batchesToUpdate.add({
          'id': batch['id'],
          'new_stock': newStock,
          'prev': batchStock,
        });
        movementsToInsert.add({
          'variant_id': variantId,
          'warehouse_id': warehouseId,
          'stock_batch_id': batch['id'],
          'order_id': orderId,
          'quantity': -deduct,
          'previous_stock': batchStock,
          'new_stock': newStock,
          'reason': 'SALE',
          'notes': 'Borrador completado — pedido #$orderId',
          if (currentProfileId != null) 'created_by': currentProfileId,
        });
        remaining -= deduct;
      }
    }

    // Actualizar lotes en paralelo (son independientes entre sí)
    await Future.wait(
      batchesToUpdate.map(
        (b) => _supabase
            .from('warehouse_stock_batches')
            .update({'available_quantity': b['new_stock']})
            .eq('id', b['id']),
      ),
    );

    // Insertar movimientos en un solo batch
    if (movementsToInsert.isNotEmpty) {
      await _supabase.from('inventory_movements').insert(movementsToInsert);
    }

    // ── 3. Registrar transacción financiera / deuda crédito ───────────────
    if (isCredito) {
      final creditResp =
          await _supabase
              .from('customer_credits')
              .select('id, current_debt')
              .eq('profile_id', customerId!)
              .single();

      final creditId = creditResp['id'] as String;
      final newDebt =
          (creditResp['current_debt'] as num).toDouble() + totalAmount;

      await _supabase
          .from('customer_credits')
          .update({
            'current_debt': newDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId);

      await _supabase.from('customer_credit_movements').insert({
        'customer_credit_id': creditId,
        'order_id': orderId,
        'movement_type': 'CHARGE',
        'amount': totalAmount,
        'payment_method': 'CRÉDITO',
        'notes': 'Activación de pedido borrador #$orderId',
        if (currentProfileId != null) 'created_by': currentProfileId,
      });
    } else {
      // Pago directo: buscar cuenta financiera por nombre de método de pago
      final accountsResp = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');
      final accounts = List<Map<String, dynamic>>.from(accountsResp);

      Map<String, dynamic>? targetAccount;
      if (accounts.isNotEmpty) {
        try {
          targetAccount = accounts.firstWhere(
            (a) =>
                (a['name'] as String).toUpperCase().contains(
                  paymentMethod.toUpperCase(),
                ) ||
                paymentMethod.toUpperCase().contains(
                  (a['name'] as String).toUpperCase(),
                ),
          );
        } catch (_) {
          targetAccount = accounts.first;
        }
      }

      if (targetAccount != null) {
        await _supabase.rpc('register_financial_movement', params: {
          'p_account_id': targetAccount['id'],
          'p_movement_type': 'INCOME',
          'p_amount': totalAmount,
          'p_description': 'Cobro de venta — Pedido #$orderId',
          'p_reference_type': 'orders',
          'p_reference_id': orderId,
          'p_created_by': currentProfileId,
        });
      }
    }

    // ── 4. Actualizar estado del pedido ──────────────────────────────────
    final updates = <String, dynamic>{
      'status': 'COMPLETED',
      if (isCredito) ...{
        'payment_status': 'PENDING',
        'amount_paid': 0,
      } else ...{
        'payment_status': 'PAID',
        'amount_paid': totalAmount,
      },
    };
    await _supabase.from('orders').update(updates).eq('id', orderId);

    // ── 5. Wallet: puntos ganados (crédito los gana al pagar, no al borrador) ──
    if (customerId != null && !isCredito && pointsEarned > 0) {
      final earnedExists =
          await _supabase
              .from('wallet_movements')
              .select('id')
              .eq('order_id', orderId)
              .eq('movement_type', 'EARNED')
              .maybeSingle();

      if (earnedExists == null) {
        final profileData =
            await _supabase
                .from('profiles')
                .select('wallet_balance')
                .eq('id', customerId)
                .maybeSingle();

        if (profileData != null) {
          final curBal = (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
          await Future.wait([
            _supabase
                .from('profiles')
                .update({'wallet_balance': curBal + pointsEarned})
                .eq('id', customerId),
            _supabase.from('wallet_movements').insert({
              'profile_id': customerId,
              'order_id': orderId,
              'points': pointsEarned,
              'movement_type': 'EARNED',
              'description': 'Monedas obtenidas al completar pedido #$orderId',
            }),
            _supabase
                .from('orders')
                .update({'points_earned': pointsEarned})
                .eq('id', orderId),
          ]);
        }
      }
    }

    // ── 6. Wallet: puntos canjeados (REDEEMED) ───────────────────────────
    if (customerId != null && pointsUsed > 0) {
      final redeemedExists =
          await _supabase
              .from('wallet_movements')
              .select('id')
              .eq('order_id', orderId)
              .eq('movement_type', 'REDEEMED')
              .maybeSingle();

      if (redeemedExists == null) {
        final profileData =
            await _supabase
                .from('profiles')
                .select('wallet_balance')
                .eq('id', customerId)
                .maybeSingle();

        if (profileData != null) {
          final curBal = (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
          await Future.wait([
            _supabase
                .from('profiles')
                .update({
                  'wallet_balance': (curBal - pointsUsed).clamp(0, curBal),
                })
                .eq('id', customerId),
            _supabase.from('wallet_movements').insert({
              'profile_id': customerId,
              'order_id': orderId,
              'points': -pointsUsed,
              'movement_type': 'REDEEMED',
              'description': 'Canje aplicado al completar pedido #$orderId',
            }),
          ]);
        }
      }
    }
  }

  /// Cancela un pedido: revierte movimientos de wallet, inventario, finanzas y crédito.
  @override
  Future<Either<Failure, void>> cancelOrder({
    required String orderId,
    required String? customerId,
    String? currentProfileId,
    String? notesOverride,
  }) async {
    try {
      final payload = {
        'order_id': orderId,
        'selected_customer_id': customerId,
        'current_profile_id': currentProfileId,
        'notes_override': notesOverride,
      };

      await _supabase.rpc('rpc_cancel_order', params: {'payload': payload});
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Error al cancelar orden: $e'));
    }
  }

  Future<void> revertFinancialMovement({
    required String orderId,
    required String? currentProfileId,
    String? notesOverride,
  }) async {
    final origMovResp = await _supabase
        .from('account_movements')
        .select('account_id, amount')
        .eq('reference_id', orderId)
        .eq('reference_type', 'orders')
        .eq('movement_type', 'INCOME');

    for (final mov in origMovResp as List) {
      final accountId = mov['account_id'] as String;
      final origMovAmount = (mov['amount'] as num).toDouble();

      final acctResp =
          await _supabase
              .from('financial_accounts')
              .select('type, balance')
              .eq('id', accountId)
              .maybeSingle();

      if (acctResp != null) {
        await _supabase.rpc('register_financial_movement', params: {
          'p_account_id': accountId,
          'p_movement_type': 'EXPENSE',
          'p_amount': origMovAmount,
          'p_description': notesOverride ?? 'Reversión por cancelación — Pedido #$orderId',
          'p_reference_type': 'orders',
          'p_reference_id': orderId,
          'p_created_by': currentProfileId,
        });
      }
    }
  }

  Future<void> revertLoyaltyPoints({
    required String orderId,
    required String customerId,
  }) async {
    // Revertir monedas EARNED
    final earnedMov =
        await _supabase
            .from('wallet_movements')
            .select('id, points')
            .eq('order_id', orderId)
            .eq('movement_type', 'EARNED')
            .maybeSingle();

    if (earnedMov != null) {
      final pts = (earnedMov['points'] as num).toInt();
      final profileData =
          await _supabase
              .from('profiles')
              .select('wallet_balance')
              .eq('id', customerId)
              .maybeSingle();
      if (profileData != null) {
        final curBal = (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
        await Future.wait([
          _supabase
              .from('profiles')
              .update({'wallet_balance': (curBal - pts).clamp(0, curBal)})
              .eq('id', customerId),
          _supabase.from('wallet_movements').insert({
            'profile_id': customerId,
            'order_id': orderId,
            'points': -pts,
            'movement_type': 'ADJUSTMENT',
            'description':
                'Reversión de monedas por cancelación de pedido #$orderId',
          }),
        ]);
      }
    }

    // Devolver monedas canjeadas REDEEMED
    final redeemedMov =
        await _supabase
            .from('wallet_movements')
            .select('id, points')
            .eq('order_id', orderId)
            .eq('movement_type', 'REDEEMED')
            .maybeSingle();

    if (redeemedMov != null) {
      final ptsCanjeados = (redeemedMov['points'] as num).toInt().abs();
      final profileData =
          await _supabase
              .from('profiles')
              .select('wallet_balance')
              .eq('id', customerId)
              .maybeSingle();
      if (profileData != null) {
        final curBal = (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
        await Future.wait([
          _supabase
              .from('profiles')
              .update({'wallet_balance': curBal + ptsCanjeados})
              .eq('id', customerId),
          _supabase.from('wallet_movements').insert({
            'profile_id': customerId,
            'order_id': orderId,
            'points': ptsCanjeados,
            'movement_type': 'ADJUSTMENT',
            'description':
                'Devolución de monedas canjeadas por cancelación #$orderId',
          }),
        ]);
      }
    }
  }

  /// Recupera los ítems de un pedido para la generación de tickets PDF
  /// trayendo estrictamente los datos necesarios (Directiva 3: Columnas específicas y !inner).
  /// Se remueven imágenes u otros datos pesados.
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchOrderItemsForPdf(
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

    return Right(List<Map<String, dynamic>>.from(resp));
  }

  List<Map<String, dynamic>>? _cachedFinancialAccounts;

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getFinancialAccounts() async {
    if (_cachedFinancialAccounts != null && _cachedFinancialAccounts!.isNotEmpty) {
      return Right(_cachedFinancialAccounts!);
    }
    try {
      final response = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');
      final accounts = List<Map<String, dynamic>>.from(response);
      _cachedFinancialAccounts = accounts;
      return Right(accounts);
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en getFinancialAccounts: $e\n$st');
      return Left(ServerFailure(message: 'Error fetching financial accounts: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getProfileById(String profileId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, phone, wallet_balance')
          .eq('id', profileId)
          .maybeSingle();
      return Right(response);
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en getProfileById: $e\n$st');
      return Left(ServerFailure(message: 'Error fetching profile: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchCustomers(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, phone, document_number')
          .or('full_name.ilike.%$query%,phone.ilike.%$query%,document_number.ilike.%$query%')
          .limit(20);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en searchCustomers: $e\n$st');
      return Left(ServerFailure(message: 'Error searching customers: $e'));
    }
  }

  @override
  Future<Either<Failure, String?>> checkActiveCashShift() async {
    try {
      // The active shift is no longer checked in the client side.
      // We return null since the RPC register_financial_movement will handle it.
      return const Right(null);
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en checkActiveCashShift: $e\n$st');
      return Left(ServerFailure(message: 'Error checking active cash shift: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> registerCreditPayment({
    required String? customerId,
    required String? creditId,
    required double amount,
    required String accountId,
    required String orderId,
    required String notes,
    required String? shiftId,
  }) async {
    try {
      final rpcResp = await _supabase.rpc(
        'register_credit_payment_rpc',
        params: {
          'p_customer_id': customerId,
          'p_credit_id': creditId,
          'p_amount': amount,
          'p_account_id': accountId,
          'p_order_id': orderId,
          'p_notes': notes,
          'p_shift_id': shiftId,
        },
      );

      if (rpcResp != null && rpcResp['success'] == true) {
        return const Right(null);
      } else {
        return Left(ServerFailure(message: 'El RPC falló o no devolvió éxito. Resp: $rpcResp'));
      }
    } catch (e, st) {
      debugPrint('🔴 [OrdersRepo] Error en registerCreditPayment: $e\n$st');
      return Left(ServerFailure(message: 'Error al registrar pago en base de datos: $e'));
    }
  }

   @override
  Stream<Either<Failure, int>> watchPendingOrdersCount() {
    final controller = StreamController<Either<Failure, int>>.broadcast();
    RealtimeChannel? channel;

    Future<void> fetchCount() async {
      try {
        final response = await _supabase
            .from('orders')
            .select('id')
            .eq('status', 'PENDING')
            .count(CountOption.exact);
        
        if (!controller.isClosed) {
          controller.add(Right(response.count));
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(Left(ServerFailure(message: 'Error fetching count: $e')));
        }
      }
    }

    // Suscripción al crearse el stream
    controller.onListen = () async {
      await fetchCount();
      channel = _supabase.channel('public:orders:pending_count')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            // Cada vez que hay una inserción/actualización/borrado en 'orders', consultamos el count
            fetchCount();
          },
        );
      channel!.subscribe();
    };

    // Limpieza al cerrarse el stream
    controller.onCancel = () async {
      await channel?.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }

}
