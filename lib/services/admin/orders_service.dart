import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/order_item_model.dart';

/// Servicio para operaciones pesadas sobre pedidos (órdenes).
/// Centraliza la lógica de negocio que antes vivía directamente en OrdersScreen.
class OrdersService {
  static final OrdersService _instance = OrdersService._internal();
  factory OrdersService() => _instance;
  OrdersService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Resuelve el profileId del usuario autenticado actual.
  Future<String?> _getCurrentProfileId() async {
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null) return null;
    final resp =
        await _supabase
            .from('profiles')
            .select('id')
            .eq('auth_user_id', authUserId)
            .maybeSingle();
    return resp?['id'] as String?;
  }

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
  }) async {
    final currentProfileId = await _getCurrentProfileId();
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
        String? shiftId;
        if (targetAccount['type'] == 'CAJA') {
          final shiftResp =
              await _supabase
                  .from('cash_shifts')
                  .select('id')
                  .eq('account_id', targetAccount['id'] as String)
                  .eq('status', 'OPEN')
                  .maybeSingle();
          shiftId = shiftResp?['id'] as String?;
        }

        await _supabase.from('account_movements').insert({
          'account_id': targetAccount['id'],
          'movement_type': 'INCOME',
          'amount': totalAmount,
          'description': 'Cobro de venta — Pedido #$orderId',
          'reference_type': 'orders',
          'reference_id': orderId,
          if (shiftId != null) 'shift_id': shiftId,
          if (currentProfileId != null) 'created_by': currentProfileId,
        });

        final currentBalance =
            (targetAccount['balance'] as num?)?.toDouble() ?? 0.0;
        await _supabase
            .from('financial_accounts')
            .update({'balance': currentBalance + totalAmount})
            .eq('id', targetAccount['id'] as String);
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
  Future<void> cancelOrder({
    required String orderId,
    required String? customerId,
    String? currentProfileId,
    String? notesOverride,
  }) async {
    final orderData =
        await _supabase
            .from('orders')
            .select('status, warehouse_id, total_amount, amount_paid, payment_method, customer_id')
            .eq('id', orderId)
            .single();

    final status = orderData['status'] as String;
    final origCustomerId = orderData['customer_id'] as String?;
    
    if (status == 'COMPLETED') {
      final warehouseId = orderData['warehouse_id'] as String?;
      final origAmount = (orderData['total_amount'] as num).toDouble();
      final amountPaid = (orderData['amount_paid'] as num).toDouble();
      final origPaymentMethod = orderData['payment_method'] as String;

      // Fetch items
      final itemsResp = await _supabase.from('order_items').select().eq('order_id', orderId);
      final items = (itemsResp as List).map((i) => OrderItemModel.fromJson(i)).toList();

      // Revertir stock
      await Future.wait(
        items.map(
          (item) => _revertItemStock(
            orderId: orderId,
            item: item,
            warehouseId: warehouseId,
            currentProfileId: currentProfileId,
            notesOverride: notesOverride,
          ),
        ),
      );

      // Revertir crédito o movimiento financiero
      if (origPaymentMethod == 'CRÉDITO' && origCustomerId != null) {
        await revertCreditDebt(
          customerId: origCustomerId,
          orderId: orderId,
          origAmount: origAmount,
          amountPaid: amountPaid,
          currentProfileId: currentProfileId,
          notesOverride: notesOverride,
        );
        if (amountPaid > 0) {
          await revertFinancialMovement(
            orderId: orderId,
            currentProfileId: currentProfileId,
            notesOverride: notesOverride,
          );
        }
      } else if (origPaymentMethod != 'CRÉDITO') {
        await revertFinancialMovement(
          orderId: orderId,
          currentProfileId: currentProfileId,
          notesOverride: notesOverride,
        );
      }
    }

    // Revertir monedas de fidelidad (EARNED o REDEEMED), aplica para PENDING y COMPLETED
    if (origCustomerId != null) {
      await revertLoyaltyPoints(orderId: orderId, customerId: origCustomerId);
    }

    // Actualizar la orden a CANCELLED o RETURNED
    final newStatus = status == 'COMPLETED' ? 'RETURNED' : 'CANCELLED';
    await _supabase
        .from('orders')
        .update({
          'status': newStatus,
          'payment_status': 'PAID',
          'amount_paid': 0,
        })
        .eq('id', orderId);
  }

  Future<void> _revertItemStock({
    required String orderId,
    required OrderItemModel item,
    required String? warehouseId,
    required String? currentProfileId,
    String? notesOverride,
  }) async {
    final safeVariantId = item.variantId ?? '';
    final movs = await _supabase
        .from('inventory_movements')
        .select('quantity, stock_batch_id')
        .eq('order_id', orderId)
        .eq('variant_id', safeVariantId)
        .eq('reason', 'SALE');

    final insertions = <Future>[];
    for (final mov in (movs as List)) {
      final batchId = mov['stock_batch_id'] as String?;
      final qtyDeducted = ((mov['quantity'] as num).toDouble()).abs().toInt();
      if (batchId == null || qtyDeducted <= 0) continue;

      final batchResp =
          await _supabase
              .from('warehouse_stock_batches')
              .select('available_quantity')
              .eq('id', batchId)
              .maybeSingle();

      if (batchResp == null) continue;
      final currentStock = (batchResp['available_quantity'] as num).toInt();
      final newStock = currentStock + qtyDeducted;

      insertions.add(
        _supabase
            .from('warehouse_stock_batches')
            .update({'available_quantity': newStock})
            .eq('id', batchId),
      );
      insertions.add(
        _supabase.from('inventory_movements').insert({
          'variant_id': safeVariantId,
          'warehouse_id': warehouseId,
          'stock_batch_id': batchId,
          'order_id': orderId,
          'quantity': qtyDeducted,
          'previous_stock': currentStock,
          'new_stock': newStock,
          'unit_cost': item.unitCost,
          'reason': 'RETURN',
          'notes':
              notesOverride ?? 'Devolución de inventario — Pedido #$orderId',
          if (currentProfileId != null) 'created_by': currentProfileId,
        }),
      );
    }
    await Future.wait(insertions);
  }

  Future<void> revertCreditDebt({
    required String customerId,
    required String orderId,
    required double origAmount,
    required double amountPaid,
    required String? currentProfileId,
    String? notesOverride,
  }) async {
    final creditResp =
        await _supabase
            .from('customer_credits')
            .select('id, current_debt')
            .eq('profile_id', customerId)
            .maybeSingle();
    if (creditResp == null) return;

    final creditId = creditResp['id'] as String;
    final currentDebt = (creditResp['current_debt'] as num).toDouble();
    
    // Calculamos la reducción neta de la deuda
    final netReduction = origAmount - amountPaid;
    final newDebt = (currentDebt - netReduction).clamp(0.0, double.infinity);

    final futures = <Future>[];
    futures.add(
      _supabase
          .from('customer_credits')
          .update({
            'current_debt': newDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId),
    );

    // Movimiento para deshacer el cargo original de la orden
    futures.add(
      _supabase.from('customer_credit_movements').insert({
        'customer_credit_id': creditId,
        'order_id': orderId,
        'movement_type': 'PAYMENT',
        'amount': origAmount,
        'notes': notesOverride ?? 'Reversión por cancelación de pedido #$orderId',
        if (currentProfileId != null) 'created_by': currentProfileId,
      }),
    );

    // Movimiento para deshacer los abonos físicos que se le están devolviendo al cliente
    if (amountPaid > 0) {
      futures.add(
        _supabase.from('customer_credit_movements').insert({
          'customer_credit_id': creditId,
          'order_id': orderId,
          'movement_type': 'CHARGE',
          'amount': amountPaid,
          'notes': 'Reversión de abonos por cancelación de pedido #$orderId',
          if (currentProfileId != null) 'created_by': currentProfileId,
        }),
      );
    }

    await Future.wait(futures);
  }

  Future<void> revertFinancialMovement({
    required String orderId,
    required String? currentProfileId,
    String? notesOverride,
  }) async {
    final origMovResp =
        await _supabase
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

      String? shiftId;
      if (acctResp != null && acctResp['type'] == 'CAJA') {
        final shiftResp =
            await _supabase
                .from('cash_shifts')
                .select('id')
                .eq('account_id', accountId)
                .eq('status', 'OPEN')
                .maybeSingle();
        shiftId = shiftResp?['id'] as String?;
      }

      final insertFuture = _supabase.from('account_movements').insert({
        'account_id': accountId,
        'movement_type': 'EXPENSE',
        'amount': origMovAmount,
        'description':
            notesOverride ?? 'Reversión por cancelación — Pedido #$orderId',
        'reference_type': 'orders',
        'reference_id': orderId,
        if (shiftId != null) 'shift_id': shiftId,
        if (currentProfileId != null) 'created_by': currentProfileId,
      });

      if (acctResp != null) {
        final currentBalance = (acctResp['balance'] as num?)?.toDouble() ?? 0.0;
        await Future.wait([
          insertFuture,
          _supabase
              .from('financial_accounts')
              .update({
                'balance': (currentBalance - origMovAmount).clamp(
                  0.0,
                  double.infinity,
                ),
              })
              .eq('id', accountId),
        ]);
      } else {
        await insertFuture;
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
}
