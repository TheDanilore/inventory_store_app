import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_orders_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_purchase_order_status_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_order_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_order_payment_method_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';

@injectable
class PurchaseOrdersCubit extends Cubit<PurchaseOrdersState> {
  final FetchPurchaseOrdersUseCase fetchPurchaseOrdersUseCase;
  final UpdatePurchaseOrderStatusUseCase updatePurchaseOrderStatusUseCase;
  final RegisterOrderPaymentUseCase registerOrderPaymentUseCase;
  final UpdateOrderPaymentMethodUseCase updateOrderPaymentMethodUseCase;

  static const int pageSize = 10;

  PurchaseOrdersCubit({
    required this.fetchPurchaseOrdersUseCase,
    required this.updatePurchaseOrderStatusUseCase,
    required this.registerOrderPaymentUseCase,
    required this.updateOrderPaymentMethodUseCase,
  }) : super(PurchaseOrdersInitial()) {
    loadOrders();
  }

  Future<void> loadOrders({
    String? searchText,
    String? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    int? page,
    bool refresh = false,
  }) async {
    final currentState = state;
    String currentSearchText = '';
    String currentStatusFilter = 'Todos';
    DateTime? currentStartDate;
    DateTime? currentEndDate;
    int currentPage = 0;
    List<dynamic> currentOrders = [];
    int currentTotalCount = 0;

    if (currentState is PurchaseOrdersLoaded) {
      currentSearchText = searchText ?? currentState.searchText;
      currentStatusFilter = statusFilter ?? currentState.statusFilter;
      // Date range needs a way to be explicitly cleared if both are null and refresh is requested.
      // But we just use ?? logic. If we need to clear it, we might need a distinct method.
      currentStartDate = startDate ?? currentState.startDate;
      currentEndDate = endDate ?? currentState.endDate;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentOrders = refresh ? [] : currentState.orders;
      currentTotalCount = currentState.totalCount;
    } else if (currentState is PurchaseOrdersLoading) {
      currentSearchText = searchText ?? currentState.searchText;
      currentStatusFilter = statusFilter ?? currentState.statusFilter;
      currentStartDate = startDate ?? currentState.startDate;
      currentEndDate = endDate ?? currentState.endDate;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentOrders = refresh ? [] : currentState.currentOrders;
      currentTotalCount = currentState.totalCount;
    } else if (currentState is PurchaseOrdersError) {
      currentSearchText = searchText ?? currentState.searchText;
      currentStatusFilter = statusFilter ?? currentState.statusFilter;
      currentStartDate = startDate ?? currentState.startDate;
      currentEndDate = endDate ?? currentState.endDate;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentOrders = refresh ? [] : currentState.currentOrders;
      currentTotalCount = currentState.totalCount;
    } else {
      currentSearchText = searchText ?? '';
      currentStatusFilter = statusFilter ?? 'Todos';
      currentStartDate = startDate;
      currentEndDate = endDate;
      currentPage = page ?? 0;
    }

    emit(
      PurchaseOrdersLoading(
        currentOrders: currentOrders,
        searchText: currentSearchText,
        statusFilter: currentStatusFilter,
        startDate: currentStartDate,
        endDate: currentEndDate,
        currentPage: currentPage,
        totalCount: currentTotalCount,
      ),
    );

    final result = await fetchPurchaseOrdersUseCase(
      page: currentPage,
      pageSize: pageSize,
      searchText: currentSearchText,
      statusFilter: currentStatusFilter,
      startDate: currentStartDate,
      endDate: currentEndDate,
    );

    result.fold(
      (failure) {
        String msg = 'Error al cargar órdenes.';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(
          PurchaseOrdersError(
            message: msg,
            currentOrders: currentOrders,
            searchText: currentSearchText,
            statusFilter: currentStatusFilter,
            startDate: currentStartDate,
            endDate: currentEndDate,
            currentPage: currentPage,
            totalCount: currentTotalCount,
          ),
        );
      },
      (data) {
        emit(
          PurchaseOrdersLoaded(
            orders: data['data'] as List<dynamic>,
            searchText: currentSearchText,
            statusFilter: currentStatusFilter,
            startDate: currentStartDate,
            endDate: currentEndDate,
            currentPage: currentPage,
            totalCount: data['count'] as int,
          ),
        );
      },
    );
  }

  void setSearchText(String text) {
    loadOrders(searchText: text, page: 0, refresh: true);
  }

  void setStatusFilter(String status) {
    loadOrders(statusFilter: status, page: 0, refresh: true);
  }

  void setDateRange(DateTime? start, DateTime? end) {
    // Force set the dates using a direct update since our logic uses ??
    // We can clear it by setting them inside the function
    final currentState = state;
    if (currentState is PurchaseOrdersLoaded) {
      emit(
        PurchaseOrdersLoading(
          currentOrders: [],
          searchText: currentState.searchText,
          statusFilter: currentState.statusFilter,
          startDate: start,
          endDate: end,
          currentPage: 0,
          totalCount: currentState.totalCount,
        ),
      );
    }
    loadOrders(page: 0, refresh: true, startDate: start, endDate: end);
  }

  void clearDateRange() {
    setDateRange(null, null);
  }

  void setPage(int page) {
    loadOrders(page: page);
  }

  Future<bool> updateOrderStatus(String poId, String newStatus) async {
    if (_isProcessingAction) return false;
    _isProcessingAction = true;
    final currentState = state;
    if (currentState is! PurchaseOrdersLoaded) {
      _isProcessingAction = false;
      return false;
    }

    final result = await updatePurchaseOrderStatusUseCase(poId, newStatus);
    _isProcessingAction = false;
    return result.fold(
      (failure) {
        String msg = 'Error al actualizar estado: ${failure.message}';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(
          PurchaseOrdersError(
            message: msg,
            currentOrders: currentState.orders,
            searchText: currentState.searchText,
            statusFilter: currentState.statusFilter,
            startDate: currentState.startDate,
            endDate: currentState.endDate,
            currentPage: currentState.currentPage,
            totalCount: currentState.totalCount,
          ),
        );
        return false;
      },
      (_) {
        loadOrders();
        return true;
      },
    );
  }

  void clearError() {
    final currentState = state;
    if (currentState is PurchaseOrdersError) {
      emit(
        PurchaseOrdersLoaded(
          orders: currentState.currentOrders,
          searchText: currentState.searchText,
          statusFilter: currentState.statusFilter,
          startDate: currentState.startDate,
          endDate: currentState.endDate,
          currentPage: currentState.currentPage,
          totalCount: currentState.totalCount,
        ),
      );
    }
  }

  bool _isProcessingAction = false;

  // ── Registrar Pago de Orden (Zero Egress) ─────────────────────────────────
  Future<void> registerOrderPayment(RegisterOrderPaymentParams params) async {
    if (_isProcessingAction) return;
    _isProcessingAction = true;
    final previousState = state;

    final result = await registerOrderPaymentUseCase(params);
    _isProcessingAction = false;

    result.fold(
      (failure) {
        emit(PurchaseOrderActionError(message: failure.message));
        if (previousState is PurchaseOrdersLoaded) {
          emit(previousState);
        }
      },
      (_) {
        // Zero Egress: mutar amount_paid y payment_status en la lista RAM
        if (previousState is PurchaseOrdersLoaded) {
          final updatedOrders = previousState.orders.map((o) {
            final dynamic order = o;
            final dynamic oId = order is Map ? order['id'] : null;
            if (oId == params.orderId) {
              final currentPaid = (order['amount_paid'] as num?)?.toDouble() ?? 0.0;
              final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
              final newPaid = currentPaid + params.amount;
              final newStatus = newPaid >= totalAmount ? 'PAID' : 'PARTIAL';
              return {...(order as Map<String, dynamic>), 'amount_paid': newPaid, 'payment_status': newStatus};
            }
            return o;
          }).toList();
          
          emit(PurchaseOrderActionSuccess(
            message: 'Pago de S/ ${params.amount.toStringAsFixed(2)} registrado correctamente.',
            orderId: params.orderId,
            newAmountPaid: params.amount,
          ));
          
          // Re-emitir el estado principal para restaurar la lista en pantalla
          emit(previousState.copyWith(orders: updatedOrders));
        }
      },
    );
  }

  // ── Cambiar Método de Pago (Zero Egress) ─────────────────────────────────
  Future<void> updateOrderPaymentMethod(
    UpdateOrderPaymentMethodParams params,
  ) async {
    final previousState = state;

    final result = await updateOrderPaymentMethodUseCase(params);

    result.fold(
      (failure) {
        emit(PurchaseOrderActionError(message: failure.message));
        if (previousState is PurchaseOrdersLoaded) {
          emit(previousState);
        }
      },
      (_) {
        // Zero Egress: mutar payment_method en la lista RAM
        if (previousState is PurchaseOrdersLoaded) {
          final updatedOrders = previousState.orders.map((o) {
            final dynamic order = o;
            final dynamic oId = order is Map ? order['id'] : null;
            if (oId == params.orderId) {
              return {...(order as Map<String, dynamic>), 'payment_method': params.newMethod};
            }
            return o;
          }).toList();
          
          emit(
            PurchaseOrderActionSuccess(
              message: 'Método de pago actualizado a ${params.newMethod}.',
              orderId: params.orderId,
              newPaymentMethod: params.newMethod,
            ),
          );
          
          // Re-emitir el estado principal para restaurar la lista en pantalla
          emit(previousState.copyWith(orders: updatedOrders));
        }
      },
    );
  }
}
