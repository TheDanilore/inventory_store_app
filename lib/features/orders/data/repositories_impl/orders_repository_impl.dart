import 'dart:io' show SocketException;

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/data/datasources/orders_cache_manager.dart';
import 'package:inventory_store_app/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

@LazySingleton(as: OrdersRepository)
class OrdersRepositoryImpl implements OrdersRepository {
  final OrdersRemoteDataSource _remoteDataSource;
  final OrdersCacheManager _cacheManager;

  OrdersRepositoryImpl({
    OrdersRemoteDataSource? remoteDataSource,
    OrdersCacheManager? cacheManager,
  }) : _remoteDataSource = remoteDataSource ?? sl<OrdersRemoteDataSource>(),
       _cacheManager = cacheManager ?? sl<OrdersCacheManager>();

  @override
  ({List<OrderEntity> orders, int total})? getCachedFilteredOrders({
    String? customerIdFilter,
    required String statusFilter,
    required String paymentStatusFilter,
    String? warehouseFilter,
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
    required int limit,
    required int offset,
  }) {
    return _cacheManager.getCachedFilteredOrders(
      customerIdFilter: customerIdFilter,
      statusFilter: statusFilter,
      paymentStatusFilter: paymentStatusFilter,
      warehouseFilter: warehouseFilter,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }

  @override
  OrderEntity? getCachedOrder(String orderId) =>
      _cacheManager.getCachedOrder(orderId);

  @override
  List<OrderItemEntity>? getCachedOrderItems(String orderId) =>
      _cacheManager.getCachedOrderItems(orderId);

  @override
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(
    String profileId, {
    int limit = 10,
    DateTime? lastCreatedAt,
  }) async {
    try {
      final orders = await _remoteDataSource.getCustomerOrders(
        profileId,
        limit: limit,
        lastCreatedAt: lastCreatedAt,
      );
      return Right(orders);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en getCustomerOrders',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(
          message: 'Error de base de datos al obtener pedidos: ${e.message}',
        ),
      );
    } on SocketException catch (e, st) {
      LoggerService.e(
        'SocketException en getCustomerOrders',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(message: 'Sin conexión a internet. Verifique su red.'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getCustomerOrders',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(message: 'No se pudieron cargar los pedidos.'),
      );
    }
  }

  @override
  Future<Either<Failure, List<OrderEntity>>> getPendingOrdersByCustomer(
    String customerId,
  ) async {
    try {
      final orders = await _remoteDataSource.getPendingOrdersByCustomer(
        customerId,
      );
      return Right(orders);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en getPendingOrdersByCustomer: ${e.message}',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(
          message: 'Error al consultar órdenes pendientes: ${e.message}',
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getPendingOrdersByCustomer',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
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
    String? warehouseFilter,
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
    required int limit,
    required int offset,
    bool forceRefresh = false,
  }) async {
    final cacheKey = OrdersCacheManager.buildFilteredOrdersKey(
      customerIdFilter: customerIdFilter,
      statusFilter: statusFilter,
      paymentStatusFilter: paymentStatusFilter,
      warehouseFilter: warehouseFilter,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );

    if (!forceRefresh) {
      final cached = _cacheManager.getCachedFilteredOrders(
        customerIdFilter: customerIdFilter,
        statusFilter: statusFilter,
        paymentStatusFilter: paymentStatusFilter,
        warehouseFilter: warehouseFilter,
        startDate: startDate,
        endDate: endDate,
        searchQuery: searchQuery,
        limit: limit,
        offset: offset,
      );
      if (cached != null) {
        return Right(cached);
      }
    }

    try {
      final res = await _remoteDataSource.getFilteredOrders(
        customerIdFilter: customerIdFilter,
        statusFilter: statusFilter,
        paymentStatusFilter: paymentStatusFilter,
        warehouseFilter: warehouseFilter,
        startDate: startDate,
        endDate: endDate,
        searchQuery: searchQuery,
        limit: limit,
        offset: offset,
      );

      _cacheManager.cacheFilteredOrders(cacheKey, res.orders, res.total);
      return Right((orders: res.orders, total: res.total));
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en getFilteredOrders',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(
          message: 'Error de base de datos al consultar pedidos: ${e.message}',
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getFilteredOrders',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      final errStr = e.toString().toLowerCase();
      if (e is SocketException ||
          errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        return const Left(ServerFailure(message: 'Sin conexión a internet.'));
      }
      return Left(ServerFailure(message: 'Error al obtener pedidos: $e'));
    }
  }

  @override
  Future<Either<Failure, OrderEntity>> getOrderById(String orderId) async {
    final cached = _cacheManager.getCachedOrder(orderId);
    if (cached != null) {
      return Right(cached);
    }

    try {
      final order = await _remoteDataSource.getOrderById(orderId);
      if (order == null) {
        LoggerService.e(
          'getOrderById: Pedido no encontrado para id: $orderId',
          tag: 'OrdersRepo',
        );
        return const Left(ServerFailure(message: 'Pedido no encontrado.'));
      }
      _cacheManager.cacheOrder(order);
      return Right(order);
    } catch (e, st) {
      LoggerService.e(
        'Error en getOrderById: $orderId',
        error: e,
        stackTrace: st,
        tag: 'OrdersRepo',
      );
      return const Left(ServerFailure(message: 'No se pudo cargar el pedido.'));
    }
  }

  @override
  Future<Either<Failure, List<OrderItemEntity>>> getOrderItems(
    String orderId,
  ) async {
    final cached = _cacheManager.getCachedOrderItems(orderId);
    if (cached != null) {
      return Right(cached);
    }

    try {
      final items = await _remoteDataSource.getOrderItems(orderId);
      _cacheManager.cacheOrderItems(orderId, items);
      return Right(items);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en getOrderItems',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(
          message: 'Error al cargar ítems del pedido: ${e.message}',
        ),
      );
    } on SocketException catch (e, st) {
      LoggerService.e(
        'SocketException en getOrderItems',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(
          message: 'Sin conexión a internet al consultar el detalle.',
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getOrderItems',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(message: 'No se pudo obtener el detalle de la orden.'),
      );
    }
  }

  @override
  Future<
    Either<
      Failure,
      ({
        List<CartItemEntity> validItems,
        List<String> outOfStock,
        List<String> priceChanged,
      })
    >
  >
  validateReorderItems(List<OrderItemEntity> items) async {
    try {
      final result = await _remoteDataSource.validateReorderItems(items);
      return Right(result);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en validateReorderItems',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al verificar stock: ${e.message}'),
      );
    } on SocketException catch (e, st) {
      LoggerService.e(
        'SocketException en validateReorderItems',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(message: 'Sin conexión para validar disponibilidad.'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en validateReorderItems',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(
          message: 'No se pudo verificar el inventario para reordenar.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateOrderStatus({
    required OrderEntity order,
    required String newStatus,
    required String? currentProfileId,
  }) async {
    try {
      final effectiveProfileId = await _remoteDataSource
          .resolveCurrentProfileId(currentProfileId);

      if (newStatus == 'COMPLETED' &&
          (order.status == 'PENDING' || order.status == 'DRAFT')) {
        return await saveOrderChanges(
          orderId: order.id,
          originalStatus: order.status,
          newStatus: newStatus,
          paymentMethod: order.paymentMethod,
          selectedCustomerId: order.customerId,
          customerNameToSave: order.customerName,
          items: const [],
          pointsUsed: order.pointsUsed,
          pointsEarned: order.pointsEarned,
          totalAmount: order.totalAmount,
          totalProfit: order.totalProfit,
          batchOverrides: {},
          currentProfileId: effectiveProfileId,
        );
      } else if (newStatus == 'CANCELLED' || newStatus == 'RETURNED') {
        return await cancelOrder(
          orderId: order.id,
          customerId: order.customerId,
          currentProfileId: effectiveProfileId,
        );
      } else {
        await _remoteDataSource.updateOrderStatusDirect(
          orderId: order.id,
          newStatus: newStatus,
          effectiveProfileId: effectiveProfileId,
        );
        _cacheManager.updateOrderStatusInCache(order.id, newStatus);
        _cacheManager.evictOrderItems(order.id);
        return const Right(null);
      }
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en updateOrderStatus',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(
          message: 'Error de base de datos al actualizar el estado.',
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en updateOrderStatus',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return const Left(
        ServerFailure(message: 'Error inesperado al actualizar el estado.'),
      );
    }
  }

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
      final effectiveProfileId = await _remoteDataSource
          .resolveCurrentProfileId(currentProfileId);
      final wasCompleted = originalStatus.toUpperCase() == 'COMPLETED';
      final isNowCompleted = newStatus.toUpperCase() == 'COMPLETED';
      final isNowCancelled = newStatus.toUpperCase() == 'CANCELLED';

      if (isNowCompleted &&
          (paymentMethod == 'POR ACORDAR' || paymentMethod.trim().isEmpty)) {
        return const Left(
          ServerFailure(message: '__PAYMENT_METHOD_REQUIRED__'),
        );
      }

      final payload = {
        'order_id': orderId,
        'payment_method': paymentMethod,
        'selected_customer_id': selectedCustomerId,
        'customer_name_to_save': customerNameToSave,
        'points_used': pointsUsed,
        'points_earned': pointsEarned,
        'total_amount': totalAmount,
        'total_profit': totalProfit,
        'current_profile_id': effectiveProfileId,
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

      if (!wasCompleted && isNowCompleted) {
        await _remoteDataSource.completeOrderRpc(payload);
        _cacheManager.updateOrderStatusInCache(orderId, 'COMPLETED');
        _cacheManager.evictOrderItems(orderId);
        return const Right(null);
      } else if (wasCompleted && isNowCancelled) {
        return await cancelOrder(
          orderId: orderId,
          customerId: selectedCustomerId,
          currentProfileId: effectiveProfileId,
          notesOverride: notesOverride,
        );
      }

      const String creditPaymentType = 'CRÉDITO';
      final isCredit = paymentMethod.toUpperCase() == creditPaymentType;
      final int finalPointsUsed = isCredit ? 0 : pointsUsed;
      final int finalPointsEarned = isCredit ? 0 : pointsEarned;
      final String paymentStatus = isCredit ? 'PENDING' : 'PAID';
      final double amountPaid = isCredit ? 0 : totalAmount;

      final orderUpdate = {
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
        'updated_by': effectiveProfileId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

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

      await _remoteDataSource.saveOrderDraftDirect(
        orderId: orderId,
        orderUpdate: orderUpdate,
        upsertItems: upsertPayload,
      );

      _cacheManager.updateOrderStatusInCache(orderId, newStatus);
      _cacheManager.evictOrderItems(orderId);
      return const Right(null);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en saveOrderChanges',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(
          message: 'Error de base de datos al guardar: ${e.message}',
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error en saveOrderChanges',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error al guardar: $e'));
    }
  }

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
        customerId: null,
        currentProfileId: currentProfileId,
        notesOverride:
            notesOverride ?? 'Reembolso por devolución · Pedido #$orderId',
      );
      return const Right(null);
    } catch (e, st) {
      LoggerService.e(
        'Error en processReturn',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error al registrar devolución: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> cancelOrder({
    required String orderId,
    required String? customerId,
    String? currentProfileId,
    String? notesOverride,
  }) async {
    try {
      final effectiveProfileId = await _remoteDataSource
          .resolveCurrentProfileId(currentProfileId);
      final payload = {
        'order_id': orderId,
        'selected_customer_id': customerId,
        'current_profile_id': effectiveProfileId,
        'notes_override': notesOverride,
      };

      await _remoteDataSource.cancelOrderRpc(payload);
      _cacheManager.updateOrderStatusInCache(orderId, 'CANCELLED');
      _cacheManager.evictOrderItems(orderId);
      return const Right(null);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en cancelOrder',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de BD al cancelar orden: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en cancelOrder',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error al cancelar orden: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchOrderItemsForPdf(
    String orderId,
  ) async {
    try {
      final resp = await _remoteDataSource.fetchOrderItemsForPdf(orderId);
      return Right(resp);
    } catch (e, st) {
      LoggerService.e(
        'Error en fetchOrderItemsForPdf',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al obtener ítems para PDF: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getFinancialAccounts({
    bool forceRefresh = false,
  }) async {
    final cached = _cacheManager.getCachedFinancialAccounts(
      forceRefresh: forceRefresh,
    );
    if (cached != null) {
      return Right(cached);
    }
    try {
      final accounts = await _remoteDataSource.getFinancialAccounts();
      _cacheManager.cacheFinancialAccounts(accounts);
      return Right(accounts);
    } catch (e, st) {
      LoggerService.e(
        'Error en getFinancialAccounts',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
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
      final response = await _remoteDataSource.getProfileById(profileId);
      return Right(response);
    } catch (e, st) {
      LoggerService.e(
        'Error en getProfileById',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error fetching profile: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchCustomers(
    String query,
  ) async {
    try {
      final response = await _remoteDataSource.searchCustomers(query);
      return Right(response);
    } catch (e, st) {
      LoggerService.e(
        'Error en searchCustomers',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error searching customers: $e'));
    }
  }

  @override
  Future<Either<Failure, String?>> checkActiveCashShift() async {
    try {
      final shiftId = await _remoteDataSource.checkActiveCashShift();
      return Right(shiftId);
    } catch (e, st) {
      LoggerService.e(
        'Error en checkActiveCashShift',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
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
      final rpcResp = await _remoteDataSource.registerCreditPaymentRpc({
        'p_customer_id': customerId,
        'p_credit_id': creditId,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_order_id': orderId,
        'p_notes': notes,
        'p_shift_id': shiftId,
      });

      if (rpcResp != null && rpcResp['success'] == true) {
        final cached = _cacheManager.getCachedOrder(orderId);
        if (cached != null) {
          final newPaid = cached.amountPaid + amount;
          final newStatus = newPaid >= cached.totalAmount ? 'PAID' : 'PARTIAL';
          _cacheManager.updateOrderInCache(
            cached.copyWith(amountPaid: newPaid, paymentStatus: newStatus),
          );
        } else {
          _cacheManager.evictOrder(orderId);
        }
        return const Right(null);
      } else {
        final errorMsg =
            rpcResp is Map
                ? (rpcResp['error'] ?? rpcResp.toString())
                : rpcResp?.toString() ?? 'Error desconocido';
        return Left(
          ServerFailure(message: 'Error al registrar abono: $errorMsg'),
        );
      }
    } catch (e, st) {
      LoggerService.e(
        'Error en registerCreditPayment',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al registrar pago en base de datos: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<BatchAssignmentModel>>> fetchBatchesForVariant(
    String variantId,
    String warehouseId,
  ) async {
    try {
      final batches = await _remoteDataSource.fetchBatchesForVariant(
        variantId,
        warehouseId,
      );
      return Right(batches);
    } catch (e, st) {
      LoggerService.e(
        'Error fetching batches for variant $variantId in warehouse $warehouseId',
        tag: 'OrdersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error al consultar lotes: $e'));
    }
  }

  @override
  Stream<Either<Failure, int>> watchPendingOrdersCount() {
    return _remoteDataSource
        .watchPendingOrdersCount()
        .map<Either<Failure, int>>((count) => Right(count))
        .handleError((error) {
          return Left<Failure, int>(
            ServerFailure(message: 'Error en stream de órdenes: $error'),
          );
        });
  }
}
