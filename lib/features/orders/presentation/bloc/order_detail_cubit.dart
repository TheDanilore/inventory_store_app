import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_order_details_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/save_order_changes_uc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail_state.dart';

import 'package:injectable/injectable.dart';

@injectable
class OrderDetailCubit extends Cubit<OrderDetailState> {
  final GetOrderDetailsUc getOrderDetailsUc;
  final SaveOrderChangesUc saveOrderChangesUc;

  OrderDetailCubit({
    required this.getOrderDetailsUc,
    required this.saveOrderChangesUc,
  }) : super(const OrderDetailState());

  void setInitialOrder(OrderEntity order) {
    emit(
      state.copyWith(
        order: order,
        selectedCustomerId: order.customerId,
        currentStatus: order.status,
        pointsUsed: order.pointsUsed,
        pointsEarned: order.pointsEarned,
        paymentMethod: order.paymentMethod,
      ),
    );
  }

  void setWasModified() {
    emit(state.copyWith(wasModified: true));
  }

  void resetEditState() {
    if (state.order != null) {
      setInitialOrder(state.order!);
    }
  }

  Future<void> fetchData(String orderId) async {
    emit(state.copyWith(isLoading: true, hasError: false));

    final result = await getOrderDetailsUc(orderId);

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isLoading: false,
            hasError: true,
            errorMessage: failure.message,
          ),
        );
      },
      (details) {
        emit(
          state.copyWith(
            isLoading: false,
            order: details.order,
            items: details.items,
            selectedCustomerId: details.order.customerId,
            currentStatus: details.order.status,
            pointsUsed: details.order.pointsUsed,
            pointsEarned: details.order.pointsEarned,
            paymentMethod: details.order.paymentMethod,
          ),
        );
      },
    );
  }

  void selectCustomer(String? customerId, double ratio, double earnRate) {
    emit(
      state.copyWith(
        selectedCustomerId:
            (customerId != null && customerId.isNotEmpty) ? customerId : null,
        creditInfo: null,
      ),
    );
    _recalculatePoints(ratio, earnRate);
  }

  void updatePaymentMethod(String method, double ratio, double earnRate) {
    emit(
      state.copyWith(
        paymentMethod: method,
        pointsUsed: method == 'CRÉDITO' ? 0 : state.pointsUsed,
      ),
    );
    _recalculatePoints(ratio, earnRate);
  }

  void updateStatus(String status) {
    emit(state.copyWith(currentStatus: status));
  }

  double calculateOrderFinalAmount(double pointsToSolesRatio) {
    final subtotal = state.items.fold(0.0, (sum, i) => sum + i.subtotal);
    final discountAmount = state.order?.discountAmount ?? 0.0;
    double appliedDiscount = state.pointsUsed * pointsToSolesRatio;
    final maxDiscount = subtotal * 0.5;
    if (appliedDiscount > maxDiscount) appliedDiscount = maxDiscount;
    return (subtotal - appliedDiscount - discountAmount).clamp(
      0.0,
      double.infinity,
    );
  }

  double calculateOrderTotalProfit() {
    double totalProfit = 0.0;
    for (final item in state.items) {
      totalProfit += (item.appliedPrice - item.unitCost) * item.quantity;
    }
    return totalProfit;
  }

  void _recalculatePoints(double pointsToSolesRatio, double earningRate) {
    if (state.selectedCustomerId == null ||
        state.items.isEmpty ||
        state.paymentMethod == 'CRÉDITO' ||
        earningRate <= 0) {
      emit(state.copyWith(pointsEarned: 0));
      return;
    }

    final totalFinal = calculateOrderFinalAmount(pointsToSolesRatio);
    final earned = (totalFinal * earningRate / pointsToSolesRatio).floor();
    emit(state.copyWith(pointsEarned: earned));
  }

  void updateItemQuantity(int idx, int qty, double ratio, double earnRate) {
    final updatedItems = List<OrderItemEntity>.from(state.items);
    final item = updatedItems[idx];

    // We cannot modify final fields, we need a copyWith (assumes OrderItemEntity has it)
    updatedItems[idx] = item.copyWith(quantity: qty);

    final updatedOverrides = Map<String, List<BatchAssignmentModel>>.from(
      state.batchOverrides,
    );
    updatedOverrides.remove(item.id);

    emit(state.copyWith(items: updatedItems, batchOverrides: updatedOverrides));
    _recalculatePoints(ratio, earnRate);
  }

  void updatePointsUsed(int pts, double ratio, double earnRate) {
    emit(state.copyWith(pointsUsed: pts));
    _recalculatePoints(ratio, earnRate);
  }

  void updateBatchOverrides(String itemId, List<BatchAssignmentModel> result) {
    final updatedOverrides = Map<String, List<BatchAssignmentModel>>.from(
      state.batchOverrides,
    );
    updatedOverrides[itemId] = result;
    emit(state.copyWith(batchOverrides: updatedOverrides));
  }

  Future<bool> saveChanges({
    required String? notesOverride,
    required String manualCustomerName,
    required double pointsToSolesRatio,
  }) async {
    if (state.order == null) return false;

    emit(state.copyWith(isSaving: true));

    final customerNameToSave =
        state.selectedCustomerId != null
            ? null
            : (manualCustomerName.trim().isEmpty
                ? null
                : manualCustomerName.trim());

    final result = await saveOrderChangesUc(
      SaveOrderChangesParams(
        orderId: state.order!.id,
        originalStatus: state.order!.status,
        newStatus: state.currentStatus,
        paymentMethod: state.paymentMethod,
        selectedCustomerId: state.selectedCustomerId,
        customerNameToSave: customerNameToSave,
        items: state.items,
        pointsUsed: state.pointsUsed,
        pointsEarned: state.pointsEarned,
        totalAmount: calculateOrderFinalAmount(pointsToSolesRatio),
        totalProfit: calculateOrderTotalProfit(),
        batchOverrides: state.batchOverrides,
        notesOverride: notesOverride,
        currentProfileId: null, // Default
      ),
    );

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) {
        emit(state.copyWith(isSaving: false, wasModified: true));
        return true;
      },
    );
  }

  bool isCompleted() {
    return state.currentStatus.toUpperCase() == 'COMPLETED';
  }

  bool canToggleEdit() {
    final s = state.currentStatus.toUpperCase();
    return s != 'CANCELLED' && s != 'COMPLETED' && s != 'RETURNED';
  }

  Future<List<BatchAssignmentModel>> fetchAvailableBatches(
    String variantId,
    String warehouseId,
  ) async {
    // Mock for now until UseCase is created, or inject Supabase client later.
    // In Clean Architecture, this should be a UseCase!
    return [];
  }

  Future<dynamic> processReturn(String? notes) async {
    // Implement or leave mock for now to fix compile error
    return null;
  }
}
