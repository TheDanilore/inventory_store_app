import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/models/batch_assignment_model.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/services/admin/orders_service.dart';

/// Resultado del guardado de cambios. Permite al widget actuar sin conocer detalles.
class SaveOrderResult {
  final bool success;
  final String? errorMessage;
  final bool stockError;
  final List<String> stockMessages;

  const SaveOrderResult._({
    required this.success,
    this.errorMessage,
    this.stockError = false,
    this.stockMessages = const [],
  });

  factory SaveOrderResult.ok() => const SaveOrderResult._(success: true);
  factory SaveOrderResult.error(String msg) =>
      SaveOrderResult._(success: false, errorMessage: msg);
  factory SaveOrderResult.stockError(List<String> msgs) =>
      SaveOrderResult._(success: false, stockError: true, stockMessages: msgs);
}

/// Servicio que centraliza las operaciones de negocio del detalle de pedido.
///
/// Separa completamente la lógica de _saveChanges() y _processReturn() del widget,
/// haciéndola testeable y mantenible de forma independiente.
class OrderDetailService {
  static final OrderDetailService _instance = OrderDetailService._internal();
  factory OrderDetailService() => _instance;
  OrderDetailService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── UTILIDADES ────────────────────────────────────────────────────────────

  /// Resuelve el profileId del usuario autenticado actual.
  Future<String?> getCurrentProfileId() async {
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

  // ─── GUARDAR CAMBIOS ────────────────────────────────────────────────────────

  /// Guarda todos los cambios de un pedido en edición.
  ///
  /// Maneja los 3 escenarios posibles:
  ///   - PENDING → COMPLETED (activar borrador, descontar stock, registrar pago)
  ///   - COMPLETED → CANCELLED (revertir stock, pago, puntos de fidelidad)
  ///   - Actualización simple de datos (cliente, método de pago, etc.)
  Future<SaveOrderResult> saveOrderChanges({
    required String orderId,
    required String originalStatus,
    required String newStatus,
    required String paymentMethod,
    required String? selectedCustomerId,
    required String? customerNameToSave,
    required List<OrderItemModel> items,
    required int pointsUsed,
    required int pointsEarned,
    required double totalAmount,
    required double totalProfit,
    required Map<String, List<BatchAssignmentModel>> batchOverrides,
    String? notesOverride,
  }) async {
    try {
      final wasCompleted = originalStatus.toUpperCase() == 'COMPLETED';
      final isNowCompleted = newStatus.toUpperCase() == 'COMPLETED';
      final isNowCancelled = newStatus.toUpperCase() == 'CANCELLED';

      final currentProfileId = await getCurrentProfileId();

      // ─── BLOQUEO: método de pago vacío al completar ───────────────────────
      if (isNowCompleted &&
          (paymentMethod == 'POR ACORDAR' || paymentMethod.trim().isEmpty)) {
        return SaveOrderResult.error('__PAYMENT_METHOD_REQUIRED__');
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
        if (!result.success) return result;
      } else if (wasCompleted && isNowCancelled) {
        await OrdersService().cancelOrder(
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
              .eq('id', item.id ?? ''),
        ),
      );

      return SaveOrderResult.ok();
    } catch (e) {
      debugPrint('[OrderDetailService] saveOrderChanges error: $e');
      return SaveOrderResult.error('Error al guardar: $e');
    }
  }

  // ─── ACTIVAR BORRADOR (PENDING → COMPLETED) ────────────────────────────────

  Future<SaveOrderResult> _activateDraft({
    required String orderId,
    required String paymentMethod,
    required String? selectedCustomerId,
    required List<OrderItemModel> items,
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
      return SaveOrderResult.error('El pedido no tiene almacén asignado.');
    }

    // Validar crédito si aplica
    if (paymentMethod == 'CRÉDITO') {
      if (selectedCustomerId == null) {
        return SaveOrderResult.error(
          'No hay cliente asignado para validar el crédito.',
        );
      }
      final creditInfo =
          await _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', selectedCustomerId)
              .maybeSingle();

      if (creditInfo == null || creditInfo['is_active'] != true) {
        return SaveOrderResult.error(
          'El cliente no tiene línea de crédito activa.',
        );
      }
      final availableCredit =
          (creditInfo['credit_limit'] as num).toDouble() -
          (creditInfo['current_debt'] as num).toDouble();
      if (availableCredit < totalAmount) {
        return SaveOrderResult.error(
          'Crédito insuficiente. Disponible: S/ ${availableCredit.toStringAsFixed(2)}',
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

      final overrides = batchOverrides[item.id ?? ''];

      if (overrides != null) {
        final totalAssigned = overrides.fold(0, (s, b) => s + b.assigned);
        if (totalAssigned != qtyNeeded) {
          return SaveOrderResult.error(
            'Asignación de lotes inválida para ${item.productName ?? 'Producto'}.',
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
            '• ${item.productName} - ${item.variantLabel} (Stock real: $currentStock, Pedido: $qtyNeeded)',
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
      return SaveOrderResult.stockError(outOfStockMessages);
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

    return SaveOrderResult.ok();
  }

  // ─── DEVOLUCIÓN (widget Registrar Devolución) ──────────────────────────────

  /// Procesa la devolución completa de un pedido COMPLETED.
  /// Llama a OrdersService para revertir stock, crédito/caja, y monedas de fidelidad.
  Future<SaveOrderResult> processReturn({
    required String orderId,
    required List<OrderItemModel> items,
    String? notesOverride,
  }) async {
    try {
      final currentProfileId = await getCurrentProfileId();
      await OrdersService().cancelOrder(
        orderId: orderId,
        customerId: null, // OrdersService fetches it internally
        currentProfileId: currentProfileId,
        notesOverride:
            notesOverride ?? 'Reembolso por devolución · Pedido #$orderId',
      );
      return SaveOrderResult.ok();
    } catch (e) {
      debugPrint('[OrderDetailService] processReturn error: $e');
      return SaveOrderResult.error('Error al registrar devolución: $e');
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
      _supabase.from('customer_credit_movements').insert({
        'credit_id': creditId,
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
}
