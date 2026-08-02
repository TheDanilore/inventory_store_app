import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';

abstract class OrdersRepository {
  Future<Either<Failure, List<OrderEntity>>> getCustomerOrders(
    String profileId, {
    int limit = 10,
    DateTime? lastCreatedAt,
  });

  Future<Either<Failure, List<OrderEntity>>> getPendingOrdersByCustomer(
    String customerId,
  );

  Stream<Either<Failure, int>> watchPendingOrdersCount();

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
  });

  Future<Either<Failure, OrderEntity>> getOrderById(String orderId);
  Future<Either<Failure, List<OrderItemEntity>>> getOrderItems(String orderId);

  Future<Either<Failure, void>> updateOrderStatus({
    required OrderEntity order,
    required String newStatus,
    required String? currentProfileId,
  });
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
  });

  Future<Either<Failure, void>> processReturn({
    required String orderId,
    required List<OrderItemEntity> items,
    required String? currentProfileId,
    String? notesOverride,
  });

  Future<Either<Failure, void>> cancelOrder({
    required String orderId,
    required String? customerId,
    String? currentProfileId,
    String? notesOverride,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> fetchOrderItemsForPdf(
    String orderId,
  );

  Future<Either<Failure, List<Map<String, dynamic>>>> getFinancialAccounts();
  Future<Either<Failure, Map<String, dynamic>?>> getProfileById(
    String profileId,
  );
  Future<Either<Failure, List<Map<String, dynamic>>>> searchCustomers(
    String query,
  );
  Future<Either<Failure, String?>> checkActiveCashShift();

  Future<Either<Failure, void>> registerCreditPayment({
    required String? customerId,
    required String? creditId,
    required double amount,
    required String accountId,
    required String orderId,
    required String notes,
    required String? shiftId,
  });
}
