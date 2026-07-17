import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_orders_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_purchase_order_status_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';

@injectable
class PurchaseOrdersCubit extends Cubit<PurchaseOrdersState> {
  final FetchPurchaseOrdersUseCase fetchPurchaseOrdersUseCase;
  final UpdatePurchaseOrderStatusUseCase updatePurchaseOrderStatusUseCase;

  static const int pageSize = 10;

  PurchaseOrdersCubit({
    required this.fetchPurchaseOrdersUseCase,
    required this.updatePurchaseOrderStatusUseCase,
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

    emit(PurchaseOrdersLoading(
      currentOrders: currentOrders,
      searchText: currentSearchText,
      statusFilter: currentStatusFilter,
      startDate: currentStartDate,
      endDate: currentEndDate,
      currentPage: currentPage,
      totalCount: currentTotalCount,
    ));

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
        emit(PurchaseOrdersError(
          message: msg,
          currentOrders: currentOrders,
          searchText: currentSearchText,
          statusFilter: currentStatusFilter,
          startDate: currentStartDate,
          endDate: currentEndDate,
          currentPage: currentPage,
          totalCount: currentTotalCount,
        ));
      },
      (data) {
        emit(PurchaseOrdersLoaded(
          orders: data['data'] as List<dynamic>,
          searchText: currentSearchText,
          statusFilter: currentStatusFilter,
          startDate: currentStartDate,
          endDate: currentEndDate,
          currentPage: currentPage,
          totalCount: data['count'] as int,
        ));
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
      emit(PurchaseOrdersLoading(
        currentOrders: [],
        searchText: currentState.searchText,
        statusFilter: currentState.statusFilter,
        startDate: start,
        endDate: end,
        currentPage: 0,
        totalCount: currentState.totalCount,
      ));
    }
    loadOrders(page: 0, refresh: true, startDate: start, endDate: end);
  }

  void clearDateRange() {
    setDateRange(null, null);
  }

  void setPage(int page) {
    loadOrders(page: page);
  }

  Future<void> updateOrderStatus(String poId, String newStatus) async {
    final currentState = state;
    if (currentState is! PurchaseOrdersLoaded) return;

    final result = await updatePurchaseOrderStatusUseCase(poId, newStatus);
    result.fold(
      (failure) {
        String msg = 'Error al actualizar estado.';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(PurchaseOrdersError(
          message: msg,
          currentOrders: currentState.orders,
          searchText: currentState.searchText,
          statusFilter: currentState.statusFilter,
          startDate: currentState.startDate,
          endDate: currentState.endDate,
          currentPage: currentState.currentPage,
          totalCount: currentState.totalCount,
        ));
      },
      (_) {
        loadOrders();
      },
    );
  }

  void clearError() {
    final currentState = state;
    if (currentState is PurchaseOrdersError) {
      emit(PurchaseOrdersLoaded(
        orders: currentState.currentOrders,
        searchText: currentState.searchText,
        statusFilter: currentState.statusFilter,
        startDate: currentState.startDate,
        endDate: currentState.endDate,
        currentPage: currentState.currentPage,
        totalCount: currentState.totalCount,
      ));
    }
  }
}

