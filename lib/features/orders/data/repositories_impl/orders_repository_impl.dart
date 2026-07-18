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
    int offset = 0,
  }) async {
    try {
      final data = await _supabase
          .from('orders')
          .select('''
            *,
            profiles!orders_customer_id_fkey ( id, full_name, phone ),
            warehouses ( id, name )
          ''')
          .eq('customer_id', profileId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final orders = data.map((json) => OrderModel.fromJson(json)).toList();
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure(message: 'Error fetching orders: $e'));
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
        warehouses ( id, name )
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
        warehouses ( id, name )
      ''')
              .eq('id', orderId)
              .maybeSingle();

      if (data == null) {
        return const Left(ServerFailure(message: 'Pedido no encontrado.'));
      }
      return Right(OrderModel.fromJson(data));
    } catch (e) {
      debugPrint('Error en getOrderById: $e');
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
        products ( id, name, sku, has_variants, product_images (image_url, is_main) ),
        product_variants ( id, name, sku, product_images (image_url, is_main) )
      ''')
          .eq('order_id', orderId);

      final items = data.map((json) => OrderItemModel.fromJson(json)).toList();
      return Right(items);
    } catch (e) {
      return Left(ServerFailure(message: 'Error fetching order items: $e'));
    }
  }

  // ─── UTILIDADES ────────────────────────────────────────────────────────────

  /// Resuelve el profileId del usuario autenticado actual.

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

      // ─── ESCENARIO 1: PENDING → COMPLETED ────────────────────────────────
      if (!wasCompleted && isNowCompleted) {
        final result = await _activateDraft(
          orderId: orderId,
          paymentMethod: paymentMethod,
          selectedCustomerId: selectedCustomerId,
          items: items,
          totalAmount: totalAmount,
          batchOverrides: batchOverrides,
          currentProfileId: currentProfileId,
        );
        if (result.isLeft()) return result;
      } else if (wasCompleted && isNowCancelled) {
        await cancelOrder(
          orderId: orderId,
          customerId: selectedCustomerId,
          currentProfileId: currentProfileId,
          notesOverride: notesOverride,
        );
      }

      // ─── LÓGICA DE PUNTOS (crédito no genera en borrador) ────────────────
      int finalPointsUsed = pointsUsed;
      int finalPointsEarned = pointsEarned;
      if (paymentMethod == 'CRÉDITO') {
        finalPointsUsed = 0;
        finalPointsEarned = 0;
      }

      // ─── CALCULAR ESTADO DE PAGO ──────────────────────────────────────────
      String paymentStatus;
      double amountPaid;
      if (paymentMethod == 'CRÉDITO') {
        paymentStatus = 'PENDING';
        amountPaid = 0;
      } else if (isNowCancelled) {
        paymentStatus = 'PAID';
        amountPaid = 0;
      } else {
        paymentStatus = 'PAID';
        amountPaid = totalAmount;
      }

      // ─── ACTUALIZAR ORDEN ─────────────────────────────────────────────────
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

      // ─── FIDELIDAD: puntos al completar ──────────────────────────────────
      if (!wasCompleted && isNowCompleted && selectedCustomerId != null) {
        await _handleLoyaltyPoints(
          orderId: orderId,
          customerId: selectedCustomerId,
          pointsUsed: finalPointsUsed,
          pointsEarned: finalPointsEarned,
          paymentMethod: paymentMethod,
        );
      }

      // ─── REASIGNAR MONEDAS SI CAMBIÓ EL CLIENTE (solo en COMPLETED) ──────
      if (wasCompleted && isNowCompleted) {
        await _handleCustomerReassignment(
          orderId: orderId,
          newCustomerId: selectedCustomerId,
        );
      }

      // ─── ACTUALIZAR ITEMS INDIVIDUALES ────────────────────────────────────
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

  // ─── ACTIVAR BORRADOR (PENDING → COMPLETED) ────────────────────────────────

  Future<Either<Failure, void>> _activateDraft({
    required String orderId,
    required String paymentMethod,
    required String? selectedCustomerId,
    required List<OrderItemEntity> items,
    required double totalAmount,
    required Map<String, List<BatchAssignmentModel>> batchOverrides,
    required String? currentProfileId,
  }) async {
    final orderData =
        await _supabase
            .from('orders')
            .select('warehouse_id')
            .eq('id', orderId)
            .single();
    final warehouseId = orderData['warehouse_id'] as String?;
    if (warehouseId == null) {
      return Left(
        ServerFailure(message: 'El pedido no tiene almacén asignado.'),
      );
    }

    // Validar crédito si aplica
    if (paymentMethod == 'CRÉDITO') {
      if (selectedCustomerId == null) {
        return const Left(
          ServerFailure(
            message: 'No hay cliente asignado para validar el crédito.',
          ),
        );
      }
      final creditInfo =
          await _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', selectedCustomerId)
              .maybeSingle();

      if (creditInfo == null || creditInfo['is_active'] != true) {
        return const Left(
          ServerFailure(
            message: 'El cliente no tiene línea de crédito activa.',
          ),
        );
      }
      final availableCredit =
          (creditInfo['credit_limit'] as num).toDouble() -
          (creditInfo['current_debt'] as num).toDouble();
      if (availableCredit < totalAmount) {
        return Left(
          ServerFailure(
            message:
                'Crédito insuficiente. Disponible: S/ ${availableCredit.toStringAsFixed(2)}',
          ),
        );
      }
    }

    // Preparar movimientos de stock
    final List<String> outOfStockMessages = [];
    final List<Map<String, dynamic>> batchesToUpdate = [];
    final List<Map<String, dynamic>> movementsToInsert = [];

    for (final item in items) {
      final safeVariantId = item.variantId ?? '';
      final qtyNeeded = item.quantity;
      List<({String id, int take, int available, String batchNumber})>
      segments = [];

      final overrides = batchOverrides[item.id];

      if (overrides != null) {
        final totalAssigned = overrides.fold(0, (s, b) => s + b.assigned);
        if (totalAssigned != qtyNeeded) {
          return Left(
            ServerFailure(
              message:
                  'Asignación de lotes inválida para ${item.productName ?? 'Producto'}.',
            ),
          );
        }
        for (final b in overrides) {
          if (b.assigned > 0) {
            segments.add((
              id: b.batchId,
              take: b.assigned,
              available: b.available,
              batchNumber: b.batchNumber,
            ));
          }
        }
      } else {
        // FEFO Automático
        final batchesResp = await _supabase
            .from('warehouse_stock_batches')
            .select('id, available_quantity, batch_number')
            .eq('warehouse_id', warehouseId)
            .eq('variant_id', safeVariantId)
            .gt('available_quantity', 0)
            .order('expiry_date', ascending: true, nullsFirst: false);

        final batches = List<Map<String, dynamic>>.from(batchesResp);
        int remaining = qtyNeeded;
        for (final batch in batches) {
          if (remaining <= 0) break;
          final available = (batch['available_quantity'] as num).toInt();
          final take = remaining > available ? available : remaining;
          segments.add((
            id: batch['id'] as String,
            take: take,
            available: available,
            batchNumber: batch['batch_number'] as String,
          ));
          remaining -= take;
        }
        if (remaining > 0) {
          final currentStock = segments.fold(0, (s, seg) => s + seg.available);
          outOfStockMessages.add(
            '• ${item.productName} -  (Stock real: $currentStock, Pedido: $qtyNeeded)',
          );
          continue;
        }
      }

      for (final seg in segments) {
        batchesToUpdate.add({
          'id': seg.id,
          'available_quantity': seg.available - seg.take,
        });
        movementsToInsert.add({
          'variant_id': safeVariantId,
          'warehouse_id': warehouseId,
          'stock_batch_id': seg.id,
          'order_id': orderId,
          'quantity': -seg.take,
          'previous_stock': seg.available,
          'new_stock': seg.available - seg.take,
          'unit_cost': item.unitCost,
          'reason': 'SALE',
          'notes':
              'Pedido completado desde detalles · Lote: ${seg.batchNumber}',
          if (currentProfileId != null) 'created_by': currentProfileId,
        });
      }
    }

    if (outOfStockMessages.isNotEmpty) {
      return Left(ServerFailure(message: outOfStockMessages.join('\n')));
    }

    // Aplicar cambios de stock en paralelo
    await Future.wait(
      batchesToUpdate.map(
        (update) => _supabase
            .from('warehouse_stock_batches')
            .update({'available_quantity': update['available_quantity']})
            .eq('id', update['id']),
      ),
    );
    if (movementsToInsert.isNotEmpty) {
      await _supabase.from('inventory_movements').insert(movementsToInsert);
    }

    // Registrar pago o deuda de crédito
    if (paymentMethod == 'CRÉDITO') {
      await _registerCreditDebt(
        customerId: selectedCustomerId!,
        orderId: orderId,
        totalAmount: totalAmount,
        currentProfileId: currentProfileId,
      );
    } else {
      await _registerFinancialIncome(
        orderId: orderId,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        currentProfileId: currentProfileId,
      );
    }

    return const Right(null);
  }

  // ─── DEVOLUCIÓN (widget Registrar Devolución) ──────────────────────────────

  /// Procesa la devolución completa de un pedido COMPLETED.
  /// Llama a OrdersService para revertir stock, crédito/caja, y monedas de fidelidad.
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
        customerId: null, // OrdersService fetches it internally
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

  // ─── HELPERS INTERNOS ──────────────────────────────────────────────────────

  Future<void> _registerCreditDebt({
    required String customerId,
    required String orderId,
    required double totalAmount,
    required String? currentProfileId,
  }) async {
    final creditResp =
        await _supabase
            .from('customer_credits')
            .select('id, current_debt')
            .eq('profile_id', customerId)
            .single();
    final creditId = creditResp['id'] as String;
    final newDebt =
        (creditResp['current_debt'] as num).toDouble() + totalAmount;

    await Future.wait([
      _supabase
          .from('customer_credits')
          .update({
            'current_debt': newDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId),
      _supabase.from('customer_credits').insert({
        'customer_credit_id': creditId,
        'order_id': orderId,
        'movement_type': 'CHARGE',
        'amount': totalAmount,
        'notes': 'Activación de pedido desde detalles',
        if (currentProfileId != null) 'created_by': currentProfileId,
      }),
    ]);
  }

  Future<void> _registerFinancialIncome({
    required String orderId,
    required double totalAmount,
    required String paymentMethod,
    required String? currentProfileId,
  }) async {
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

    if (targetAccount == null) return;

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

    final currentBalance =
        (targetAccount['balance'] as num?)?.toDouble() ?? 0.0;

    await Future.wait([
      _supabase.from('account_movements').insert({
        'account_id': targetAccount['id'],
        'movement_type': 'INCOME',
        'amount': totalAmount,
        'description': 'Cobro de venta — Pedido #$orderId',
        'reference_type': 'orders',
        'reference_id': orderId,
        if (shiftId != null) 'shift_id': shiftId,
        if (currentProfileId != null) 'created_by': currentProfileId,
      }),
      _supabase
          .from('financial_accounts')
          .update({'balance': currentBalance + totalAmount})
          .eq('id', targetAccount['id'] as String),
    ]);
  }

  Future<void> _handleLoyaltyPoints({
    required String orderId,
    required String customerId,
    required int pointsUsed,
    required int pointsEarned,
    required String paymentMethod,
  }) async {
    final isCredito = paymentMethod == 'CRÉDITO';

    // Puntos ganados (crédito no genera al activar, solo al pagar)
    if (!isCredito && pointsEarned > 0) {
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
          ]);
        }
      }
    }

    // Puntos canjeados (REDEEMED)
    if (pointsUsed > 0) {
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

  Future<void> _handleCustomerReassignment({
    required String orderId,
    required String? newCustomerId,
  }) async {
    // Obtener el wallet_movement EARNED original de la orden
    final earnedMov =
        await _supabase
            .from('wallet_movements')
            .select('id, points, profile_id')
            .eq('order_id', orderId)
            .eq('movement_type', 'EARNED')
            .maybeSingle();

    if (earnedMov == null) return;

    final pts = (earnedMov['points'] as num).toInt();
    final fromProfileId = earnedMov['profile_id'] as String?;

    // Si no cambió el cliente, no hacer nada
    if (fromProfileId == newCustomerId) return;

    // Quitar monedas al cliente anterior
    if (fromProfileId != null && pts > 0) {
      final oldProfile =
          await _supabase
              .from('profiles')
              .select('wallet_balance')
              .eq('id', fromProfileId)
              .maybeSingle();
      if (oldProfile != null) {
        final oldBal = (oldProfile['wallet_balance'] as num).toInt();
        await Future.wait([
          _supabase
              .from('profiles')
              .update({'wallet_balance': (oldBal - pts).clamp(0, oldBal)})
              .eq('id', fromProfileId),
          _supabase.from('wallet_movements').insert({
            'profile_id': fromProfileId,
            'order_id': orderId,
            'points': -pts,
            'movement_type': 'ADJUSTMENT',
            'description':
                'Monedas reasignadas por cambio de cliente en pedido #$orderId',
          }),
        ]);
      }
    }

    // Dar monedas al nuevo cliente
    if (newCustomerId != null && pts > 0) {
      final newProfile =
          await _supabase
              .from('profiles')
              .select('wallet_balance')
              .eq('id', newCustomerId)
              .maybeSingle();
      if (newProfile != null) {
        final newBal = (newProfile['wallet_balance'] as num).toInt();
        await Future.wait([
          _supabase
              .from('profiles')
              .update({'wallet_balance': newBal + pts})
              .eq('id', newCustomerId),
          _supabase.from('wallet_movements').insert({
            'profile_id': newCustomerId,
            'order_id': orderId,
            'points': pts,
            'movement_type': 'ADJUSTMENT',
            'description':
                'Monedas recibidas por reasignación de pedido #$orderId',
          }),
        ]);
      }
    }

    // Actualizar el profile_id del wallet_movement EARNED original
    if (newCustomerId != null) {
      await _supabase
          .from('wallet_movements')
          .update({'profile_id': newCustomerId})
          .eq('id', earnedMov['id'] as String);
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
  @override
  Future<Either<Failure, void>> cancelOrder({
    required String orderId,
    required String? customerId,
    String? currentProfileId,
    String? notesOverride,
  }) async {
    try {
      final orderData =
          await _supabase
              .from('orders')
              .select(
                'status, warehouse_id, total_amount, amount_paid, payment_method, customer_id',
              )
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
        final itemsResp = await _supabase
            .from('order_items')
            .select()
            .eq('order_id', orderId);
        final items =
            (itemsResp as List).map((i) => OrderItemModel.fromJson(i)).toList();

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
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Error al cancelar orden: $e'));
    }
  }

  Future<void> _revertItemStock({
    required String orderId,
    required OrderItemEntity item,
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
        'notes':
            notesOverride ?? 'Reversión por cancelación de pedido #$orderId',
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
}
