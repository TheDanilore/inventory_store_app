import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_filtered_orders_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/save_order_changes_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/cancel_order_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_order_items_uc.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders_state.dart';

class OrdersCubit extends Cubit<OrdersState> {
  final GetFilteredOrdersUc _getFilteredOrdersUc;
  final SaveOrderChangesUc _saveOrderChangesUc;
  final CancelOrderUc _cancelOrderUc;
  final GetOrderItemsUc _getOrderItemsUc;
  final OrdersRepository
  _repository; // For fetchOrderItemsForPdf and general access

  OrdersCubit({
    required GetFilteredOrdersUc getFilteredOrdersUc,
    required SaveOrderChangesUc saveOrderChangesUc,
    required CancelOrderUc cancelOrderUc,
    required GetOrderItemsUc getOrderItemsUc,
    required OrdersRepository repository,
    String? customerIdFilter,
  }) : _getFilteredOrdersUc = getFilteredOrdersUc,
       _saveOrderChangesUc = saveOrderChangesUc,
       _cancelOrderUc = cancelOrderUc,
       _getOrderItemsUc = getOrderItemsUc,
       _repository = repository,
       super(OrdersState(customerIdFilter: customerIdFilter));

  void init() {
    loadOrders(reset: true);
  }

  Future<void> loadOrders({bool reset = false, bool background = false}) async {
    if (reset) {
      emit(state.copyWith(currentPage: 0, orders: [], totalRecords: 0));
    }

    if (background) {
      emit(state.copyWith(isBackgroundLoading: true, errorMessage: ''));
    } else {
      emit(state.copyWith(isLoading: true, errorMessage: ''));
    }

    final startRow = state.currentPage * OrdersState.pageSize;

    final result = await _getFilteredOrdersUc(
      GetFilteredOrdersParams(
        customerIdFilter: state.customerIdFilter,
        statusFilter: state.statusFilter,
        paymentStatusFilter: state.paymentStatusFilter,
        startDate: state.startDate,
        endDate: state.endDate,
        searchQuery: state.searchQuery,
        limit: OrdersState.pageSize,
        offset: startRow,
      ),
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isLoading: false,
            isBackgroundLoading: false,
            errorMessage: failure.message,
          ),
        );
      },
      (data) {
        emit(
          state.copyWith(
            isLoading: false,
            isBackgroundLoading: false,
            orders: data.orders,
            totalRecords: data.total,
          ),
        );
      },
    );
  }

  void goToPage(int page) {
    if (page < 0 || page >= state.totalPages || page == state.currentPage) {
      return;
    }
    emit(state.copyWith(currentPage: page));
    loadOrders();
  }

  void setStatusFilter(String val) {
    if (state.statusFilter == val) return;
    emit(state.copyWith(statusFilter: val));
    loadOrders(reset: true);
  }

  void setPaymentStatusFilter(String val) {
    if (state.paymentStatusFilter == val) return;
    emit(state.copyWith(paymentStatusFilter: val));
    loadOrders(reset: true);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    emit(state.copyWith(startDate: start, endDate: end));
    loadOrders(reset: true);
  }

  void setSearchQuery(String val) {
    if (state.searchQuery == val) return;
    emit(state.copyWith(searchQuery: val));
    loadOrders(reset: true);
  }

  Future<List<OrderItemEntity>> fetchOrderItems(String orderId) async {
    final result = await _getOrderItemsUc(orderId);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (items) => items,
    );
  }

  Future<void> updateOrderStatus(OrderEntity order, String newStatus) async {
    if (state.isOrderProcessing(order.id)) return;

    final processing = Set<String>.from(state.processingOrders)..add(order.id);
    emit(state.copyWith(processingOrders: processing));

    try {
      if (newStatus == 'COMPLETED' && order.status == 'PENDING') {
        // Fetch items first
        final itemsResult = await _getOrderItemsUc(order.id);

        await itemsResult.fold(
          (failure) async {
            // Handle error fetching items
          },
          (items) async {
            final currentProfileId =
                Supabase.instance.client.auth.currentUser?.id;

            await _saveOrderChangesUc(
              SaveOrderChangesParams(
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
              ),
            );
          },
        );
      } else if (newStatus == 'CANCELLED' || newStatus == 'RETURNED') {
        final currentProfileId = Supabase.instance.client.auth.currentUser?.id;

        await _cancelOrderUc(
          CancelOrderParams(
            orderId: order.id,
            customerId: order.customerId,
            currentProfileId: currentProfileId,
          ),
        );
      } else {
        await Supabase.instance.client
            .from('orders')
            .update({'status': newStatus})
            .eq('id', order.id);
      }

      await loadOrders(background: true);
    } finally {
      final updatedProcessing = Set<String>.from(state.processingOrders)
        ..remove(order.id);
      emit(state.copyWith(processingOrders: updatedProcessing));
    }
  }

  Future<void> generatePdfTicket(OrderEntity order) async {
    if (state.generatingPdfOrderId != null) return;
    emit(state.copyWith(generatingPdfOrderId: order.id));

    try {
      final rawItemsResult = await _repository.fetchOrderItemsForPdf(order.id);

      await rawItemsResult.fold(
        (failure) async {
          // Error handling
        },
        (rawItems) async {
          final items =
              rawItems.map((row) {
                return OrderItemModel.fromJson(Map<String, dynamic>.from(row));
              }).toList();

          await OrderPdfGenerator.shareTicket(
            order as OrderModel,
            items: items.map((e) => e).toList(),
          );
        },
      );
    } finally {
      emit(state.copyWith(generatingPdfOrderId: null));
    }
  }
}
