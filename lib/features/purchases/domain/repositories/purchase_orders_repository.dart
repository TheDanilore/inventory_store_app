import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';

abstract class PurchaseOrdersRepository {
  Future<Either<Failure, Map<String, dynamic>>> fetchOrders({
    required int page,
    required int pageSize,
    String searchText = '',
    String statusFilter = 'Todos',
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, List<PurchaseOrderItemEntity>>> fetchOrderItems(
    String poId,
  );

  Future<Either<Failure, Map<String, dynamic>?>> getPurchaseOrderById(
    String poId,
  );

  Future<Either<Failure, void>> updateOrderStatus(String poId, String status);

  Future<Either<Failure, void>> createPurchaseOrder({
    required String supplierId,
    required String supplierName,
    required String warehouseId,
    required List<dynamic> items,
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
  });

  Future<Either<Failure, void>> receiveOrderItems({
    required String poId,
    required List<Map<String, dynamic>> receivedItems,
    required String warehouseId,
  });

  Future<Either<Failure, void>> registerOrderPayment({
    required String orderId,
    required String supplierId,
    required double amount,
    required String accountId,
    required String? shiftId,
  });

  Future<Either<Failure, void>> updateOrderPaymentMethod({
    required String orderId,
    required String supplierId,
    required String newMethod,
    required String oldMethod,
    required double orderAmount,
  });

  Future<Either<Failure, Map<String, dynamic>>> getFormCatalogs();

  Future<Either<Failure, Map<String, dynamic>?>> getSupplierCredit(
    String supplierId,
  );
}

