import 'dart:async' show StreamController, Timer;
import 'dart:io' show SocketException;

import 'dart:developer' as developer;
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
            id, customer_id, customer_name, total_amount,
            discount_amount, payment_method, payment_status, amount_paid,
            status, due_date, points_used, points_earned, created_at,
            warehouse_id,
            warehouses!orders_store_id_fkey ( id, name )
          ''')
          .eq('customer_id', profileId);

      if (lastCreatedAt != null) {
        // Keyset pagination para infinito scroll estable
        query = query.lt('created_at', lastCreatedAt.toUtc().toIso8601String());
      }

      final data = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final orders = data.map((json) => OrderModel.fromJson(json)).toList();
      return Right(orders);
    } catch (e, st) {
      developer.log(
        'Error en getCustomerOrders',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(ServerFailure(message: 'Error fetching orders: $e'));
    }
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getPendingOrdersByCustomer(
    String customerId,
  ) async {
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
      developer.log(
        'Error en getPendingOrdersByCustomer',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
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

      // [OPTIMIZACIÓN N+1 → INNER JOIN] Una sola consulta con filtro por relación foránea.
      // Antes se hacía un SELECT de profiles + IN(ids) separado, que podía retornar
      // miles de IDs y romper el límite HTTP de la URL.
      final queryText = searchQuery.trim();
      if (queryText.isNotEmpty) {
        query = query.or(
          'customer_name.ilike.%$queryText%,id.ilike.%$queryText%',
        );
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
    } catch (e, st) {
      developer.log(
        'Error en getFilteredOrders',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      final errStr = e.toString().toLowerCase();
      if (e is SocketException ||
          errStr.contains('socketexception') ||
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
        developer.log(
          'getOrderById data == null para id: $orderId',
          name: 'OrdersRepo',
        );
        return const Left(ServerFailure(message: 'Pedido no encontrado.'));
      }
      return Right(OrderModel.fromJson(data));
    } catch (e, st) {
      developer.log(
        'Error en getOrderById',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
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
      developer.log(
        'Error en getOrderItems',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
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
        // [OPTIMIZACIÓN DATA EGRESS] No se descarga la lista de items al cliente solo
        // para reenviarlos. El RPC rpc_complete_order los lee directamente de la BD
        // cuando items es null/vacío, evitando un round-trip innecesario Flutter→DB→Flutter→DB.
        return await saveOrderChanges(
          orderId: order.id,
          originalStatus: order.status,
          newStatus: newStatus,
          paymentMethod: order.paymentMethod,
          selectedCustomerId: order.customerId,
          customerNameToSave: order.customerName,
          items: const [], // El RPC los obtiene internamente desde la BD
          pointsUsed: order.pointsUsed,
          pointsEarned: order.pointsEarned,
          totalAmount: order.totalAmount,
          totalProfit: order.totalProfit,
          batchOverrides: {},
          currentProfileId: currentProfileId,
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
      developer.log(
        'PostgrestException en updateOrderStatus',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(
          message: 'Error de base de datos al actualizar el estado.',
        ),
      );
    } catch (e, st) {
      developer.log(
        'Error inesperado en updateOrderStatus',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(message: 'Error inesperado al actualizar el estado.'),
      );
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
        'items':
            items
                .map(
                  (i) => {
                    'id': i.id,
                    'variant_id': i.variantId,
                    'quantity': i.quantity,
                    'unit_cost': i.unitCost,
                    'applied_price': i.appliedPrice,
                  },
                )
                .toList(),
        'batch_overrides': batchOverrides.map(
          (k, v) => MapEntry(
            k,
            v
                .map((b) => {'batch_id': b.batchId, 'assigned': b.assigned})
                .toList(),
          ),
        ),
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
      const String creditPaymentType = 'CRÉDITO';
      final isCredit = paymentMethod.toUpperCase() == creditPaymentType;
      int finalPointsUsed = isCredit ? 0 : pointsUsed;
      int finalPointsEarned = isCredit ? 0 : pointsEarned;
      String paymentStatus = isCredit ? 'PENDING' : 'PAID';
      double amountPaid = isCredit ? 0 : totalAmount;

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

      // [OPTIMIZACIÓN DATA EGRESS] Elimina N peticiones simultáneas, las agrupa en 1.
      final upsertPayload =
          items
              .map(
                (item) => {
                  'id': item.id,
                  'order_id': orderId,
                  'product_id': item.productId,
                  'variant_id': item.variantId,
                  'quantity': item.quantity,
                  'unit_cost': item.unitCost,
                  'applied_price': item.appliedPrice,
                  'net_profit':
                      (item.appliedPrice - item.unitCost) * item.quantity,
                },
              )
              .toList();

      if (upsertPayload.isNotEmpty) {
        await _supabase.from('order_items').upsert(upsertPayload);
      }

      return const Right(null);
    } on PostgrestException catch (e, st) {
      developer.log(
        'PostgrestException en saveOrderChanges',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(
          message: 'Error de base de datos al guardar: ${e.message}',
        ),
      );
    } catch (e, st) {
      developer.log(
        'Error en saveOrderChanges',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
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
    } catch (e, st) {
      developer.log(
        'Error en processReturn',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(ServerFailure(message: 'Error al registrar devolución: $e'));
    }
  }

  // ─── CÓDIGO ZOMBIE ELIMINADO ──────────────────────────────────────────────
  // Los métodos _zombiePlaceholder(), cancelOrder() antiguo, revertFinancialMovement() y
  // revertLoyaltyPoints() han sido eliminados. Toda la lógica de stock, crédito, finanzas
  // y wallet está ahora atomizada en los RPCs de la base de datos:
  //   • rpc_complete_order  → completa el pedido de forma atómica
  //   • rpc_cancel_order    → cancela y revierte todos los efectos
  // ────────────────────────────────────────────────────────────────────────────

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
    } on PostgrestException catch (e, st) {
      developer.log(
        'PostgrestException en cancelOrder',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(message: 'Error de BD al cancelar orden: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        'Error inesperado en cancelOrder',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(ServerFailure(message: 'Error al cancelar orden: $e'));
    }
  }

  /// Recupera los ítems de un pedido para la generación de tickets PDF
  /// trayendo estrictamente los datos necesarios (Directiva 3: Columnas específicas y !inner).
  /// Se remueven imágenes u otros datos pesados.
  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchOrderItemsForPdf(
    String orderId,
  ) async {
    try {
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
    } catch (e, st) {
      developer.log(
        'Error en fetchOrderItemsForPdf',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(message: 'Error al obtener ítems para PDF: $e'),
      );
    }
  }

  List<Map<String, dynamic>>? _cachedFinancialAccounts;

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
  getFinancialAccounts() async {
    if (_cachedFinancialAccounts != null &&
        _cachedFinancialAccounts!.isNotEmpty) {
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
      developer.log(
        'Error en getFinancialAccounts',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(message: 'Error fetching financial accounts: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getProfileById(
    String profileId,
  ) async {
    try {
      final response =
          await _supabase
              .from('profiles')
              .select('id, full_name, phone, wallet_balance')
              .eq('id', profileId)
              .maybeSingle();
      return Right(response);
    } catch (e, st) {
      developer.log(
        'Error en getProfileById',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(ServerFailure(message: 'Error fetching profile: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchCustomers(
    String query,
  ) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, phone, document_number')
          .or(
            'full_name.ilike.%$query%,phone.ilike.%$query%,document_number.ilike.%$query%',
          )
          .limit(20);
      return Right(List<Map<String, dynamic>>.from(response));
    } catch (e, st) {
      developer.log(
        'Error en searchCustomers',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
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
      developer.log(
        'Error en checkActiveCashShift',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(message: 'Error checking active cash shift: $e'),
      );
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
        return Left(
          ServerFailure(
            message: 'El RPC falló o no devolvió éxito. Resp: $rpcResp',
          ),
        );
      }
    } catch (e, st) {
      developer.log(
        'Error en registerCreditPayment',
        error: e,
        stackTrace: st,
        name: 'OrdersRepo',
      );
      return Left(
        ServerFailure(message: 'Error al registrar pago en base de datos: $e'),
      );
    }
  }

  @override
  Stream<Either<Failure, int>> watchPendingOrdersCount() {
    final controller = StreamController<Either<Failure, int>>.broadcast();
    RealtimeChannel? channel;
    Timer? debounceTimer;

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
      } catch (e, st) {
        developer.log(
          'Error fetching count',
          error: e,
          stackTrace: st,
          name: 'OrdersRepo',
        );
        if (!controller.isClosed) {
          controller.add(
            Left(ServerFailure(message: 'Error fetching count: $e')),
          );
        }
      }
    }

    // Suscripción al crearse el stream
    controller.onListen = () async {
      await fetchCount();
      channel = _supabase
          .channel('public:orders:pending_count')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) {
              debounceTimer?.cancel();
              debounceTimer = Timer(const Duration(milliseconds: 1500), () {
                fetchCount();
              });
            },
          );
      channel!.subscribe();
    };

    // Limpieza al cerrarse el stream
    controller.onCancel = () async {
      debounceTimer?.cancel();
      await channel?.unsubscribe();
      await controller.close();
    };

    return controller.stream;
  }
}
