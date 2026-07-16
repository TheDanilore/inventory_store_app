import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:injectable/injectable.dart';

class SaveOrderChangesParams {
  final String orderId;
  final String originalStatus;
  final String newStatus;
  final String paymentMethod;
  final String? selectedCustomerId;
  final String? customerNameToSave;
  final List<OrderItemEntity> items;
  final int pointsUsed;
  final int pointsEarned;
  final double totalAmount;
  final double totalProfit;
  final Map<String, List<BatchAssignmentModel>> batchOverrides;
  final String? currentProfileId;
  final String? notesOverride;

  SaveOrderChangesParams({
    required this.orderId,
    required this.originalStatus,
    required this.newStatus,
    required this.paymentMethod,
    required this.selectedCustomerId,
    required this.customerNameToSave,
    required this.items,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.totalAmount,
    required this.totalProfit,
    required this.batchOverrides,
    required this.currentProfileId,
    this.notesOverride,
  });
}

@lazySingleton
class SaveOrderChangesUc {
  final OrdersRepository repository;

  SaveOrderChangesUc(this.repository);

  Future<Either<Failure, void>> call(SaveOrderChangesParams params) {
    return repository.saveOrderChanges(
      orderId: params.orderId,
      originalStatus: params.originalStatus,
      newStatus: params.newStatus,
      paymentMethod: params.paymentMethod,
      selectedCustomerId: params.selectedCustomerId,
      customerNameToSave: params.customerNameToSave,
      items: params.items,
      pointsUsed: params.pointsUsed,
      pointsEarned: params.pointsEarned,
      totalAmount: params.totalAmount,
      totalProfit: params.totalProfit,
      batchOverrides: params.batchOverrides,
      currentProfileId: params.currentProfileId,
      notesOverride: params.notesOverride,
    );
  }
}
