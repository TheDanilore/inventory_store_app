import 'package:fpdart/fpdart.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_filtered_orders_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_order_items_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/update_order_status_uc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_state.dart';
import 'package:injectable/injectable.dart';

@injectable
class OrdersCubit extends Cubit<OrdersState> {
  final GetFilteredOrdersUc _getFilteredOrdersUc;
  final UpdateOrderStatusUc _updateOrderStatusUc;
  final GetOrderItemsUc _getOrderItemsUc;
  final OrdersRepository
  _repository; // For fetchOrderItemsForPdf and general access

  OrdersCubit({
    required GetFilteredOrdersUc getFilteredOrdersUc,
    required UpdateOrderStatusUc updateOrderStatusUc,
    required GetOrderItemsUc getOrderItemsUc,
    required OrdersRepository repository,
  }) : _getFilteredOrdersUc = getFilteredOrdersUc,
       _updateOrderStatusUc = updateOrderStatusUc,
       _getOrderItemsUc = getOrderItemsUc,
       _repository = repository,
       super(const OrdersState());

  void init() {
    loadOrders(reset: true);
  }

  int _currentLoadId = 0;

  Future<void> loadOrders({bool reset = false, bool background = false}) async {
    final loadId = ++_currentLoadId;

    if (reset) {
      if (state.orders.isEmpty) {
        emit(state.copyWith(
          currentPage: 0,
          orders: const [],
          totalRecords: 0,
          isLoading: true,
          isBackgroundLoading: false,
          errorMessage: '',
        ));
      } else {
        emit(state.copyWith(
          currentPage: 0,
          isBackgroundLoading: true,
          errorMessage: '',
        ));
      }
    } else if (background) {
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

    if (loadId != _currentLoadId) return;

    result.fold(
      (failure) {
        LoggerService.e(
          'Error en loadOrders: ${failure.message}',
          tag: 'OrdersCubit',
        );
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

  void updateOrderInList(OrderEntity updatedOrder) {
    final index = state.orders.indexWhere((o) => o.id == updatedOrder.id);
    if (index != -1) {
      final updatedOrders = List<OrderEntity>.from(state.orders);
      updatedOrders[index] = updatedOrder;
      emit(state.copyWith(orders: updatedOrders));
    }
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
    if (start == null && end == null) {
      emit(state.copyWith(clearDates: true));
    } else {
      emit(state.copyWith(startDate: start, endDate: end));
    }
    loadOrders(reset: true);
  }

  void setSearchQuery(String val) {
    final clean = val.trim();
    if (state.searchQuery == clean) return;
    emit(state.copyWith(searchQuery: clean));
    loadOrders(reset: true);
  }

  Future<Either<Failure, List<OrderItemEntity>>> fetchOrderItems(
    String orderId,
  ) async {
    final result = await _getOrderItemsUc(orderId);
    return result.fold((failure) {
      LoggerService.e(
        'Error en fetchOrderItems (Admin): ${failure.message}',
        tag: 'OrdersCubit',
      );
      return Left(failure);
    }, (items) => Right(items));
  }

  Future<void> updateOrderStatus(OrderEntity order, String newStatus) async {
    if (state.isOrderProcessing(order.id)) return;

    final processing = Set<String>.from(state.processingOrders)..add(order.id);
    emit(state.copyWith(processingOrders: processing));

    try {
      final result = await _updateOrderStatusUc(
        UpdateOrderStatusParams(
          order: order,
          newStatus: newStatus,
          currentProfileId: null, // Delegado al Repository
        ),
      );

      result.fold(
        (failure) {
          LoggerService.e(
            'Error actualizando estado: ${failure.message}',
            tag: 'OrdersCubit',
          );
          emit(state.copyWith(errorMessage: failure.message));
        },
        (_) {
          loadOrders(background: true);
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado actualizando estado',
        tag: 'OrdersCubit',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          errorMessage: 'Ocurrió un error inesperado al actualizar la orden.',
        ),
      );
    } finally {
      final updatedProcessing = Set<String>.from(state.processingOrders)
        ..remove(order.id);
      emit(state.copyWith(processingOrders: updatedProcessing));
    }
  }

  Future<void> generatePdfTicket(
    OrderEntity order, {
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) async {
    if (state.generatingPdfOrderId != null) return;
    emit(state.copyWith(generatingPdfOrderId: order.id));

    try {
      final rawItemsResult = await _repository.fetchOrderItemsForPdf(order.id);

      await rawItemsResult.fold(
        (failure) async {
          LoggerService.e(
            'Error obteniendo items para PDF: ${failure.message}',
            tag: 'OrdersCubit',
          );
          emit(state.copyWith(errorMessage: failure.message));
        },
        (rawItems) async {
          final items =
              rawItems.map((row) {
                return OrderItemModel.fromJson(Map<String, dynamic>.from(row));
              }).toList();

          await OrderPdfGenerator.shareTicket(
            order,
            items: items.map((e) => e).toList(),
            businessName: businessName,
            taxId: taxId,
            address: address,
            phone: phone,
          );
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error generando PDF',
        tag: 'OrdersCubit',
        error: e,
        stackTrace: st,
      );
      emit(state.copyWith(errorMessage: 'Error al generar el ticket PDF.'));
    } finally {
      emit(state.copyWith(clearPdfOrderId: true));
    }
  }
}
