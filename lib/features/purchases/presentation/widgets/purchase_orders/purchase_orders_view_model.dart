import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';

/// ViewModel optimizado para [PurchaseOrdersScreen].
/// Consolida el estado del Cubit y precalcula métricas en una única pasada O(N).
class PurchaseOrdersViewModel {
  final PurchaseOrdersCubit cubit;
  final PurchaseOrdersState state;

  late final double totalAmountFiltered;
  late final int pendingCountFiltered;
  late final double totalDebtFiltered;

  PurchaseOrdersViewModel(this.cubit, this.state) {
    _computeMetrics();
  }

  void _computeMetrics() {
    double totalAmt = 0;
    int pending = 0;
    double debt = 0;
    final list = orders;
    for (int i = 0; i < list.length; i++) {
      final o = list[i];
      if (o is PurchaseOrderModel) {
        totalAmt += o.totalAmount;
        if (o.status == 'PENDING') {
          pending++;
        }
        if (o.status != 'CANCELLED') {
          final remaining = o.totalAmount - o.amountPaid;
          if (remaining > 0) {
            debt += remaining;
          }
        }
      } else {
        final amt = (o.totalAmount ?? 0.0) as num;
        totalAmt += amt.toDouble();
        if (o.status == 'PENDING') {
          pending++;
        }
        if (o.status != 'CANCELLED') {
          final paid = (o.amountPaid ?? 0.0) as num;
          final remaining = amt - paid;
          if (remaining > 0) {
            debt += remaining.toDouble();
          }
        }
      }
    }
    totalAmountFiltered = totalAmt;
    pendingCountFiltered = pending;
    totalDebtFiltered = debt;
  }

  String get errorMessage {
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).message;
    }
    return '';
  }

  void clearError() => cubit.clearError();

  bool get isLoading =>
      (state is PurchaseOrdersLoading &&
          (state as PurchaseOrdersLoading).currentOrders.isEmpty) ||
      state is PurchaseOrdersInitial;

  bool get isBackgroundLoading =>
      state is PurchaseOrdersLoading &&
      (state as PurchaseOrdersLoading).currentOrders.isNotEmpty;

  List<dynamic> get orders {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).orders;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).currentOrders;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).currentOrders;
    }
    return const [];
  }

  int get totalCount {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).totalCount;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).totalCount;
    }
    return orders.length;
  }

  String get searchText {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).searchText;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).searchText;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).searchText;
    }
    return '';
  }

  String get statusFilter {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).statusFilter;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).statusFilter;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).statusFilter;
    }
    return 'Todos';
  }

  String get warehouseFilter {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).warehouseFilter;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).warehouseFilter;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).warehouseFilter;
    }
    return 'Todos';
  }

  List<String> get availableWarehouses {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).availableWarehouses;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).availableWarehouses;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).availableWarehouses;
    }
    return const ['Todos'];
  }

  DateTimeRange? get dateRange {
    DateTime? start;
    DateTime? end;
    if (state is PurchaseOrdersLoaded) {
      start = (state as PurchaseOrdersLoaded).startDate;
      end = (state as PurchaseOrdersLoaded).endDate;
    } else if (state is PurchaseOrdersLoading) {
      start = (state as PurchaseOrdersLoading).startDate;
      end = (state as PurchaseOrdersLoading).endDate;
    } else if (state is PurchaseOrdersError) {
      start = (state as PurchaseOrdersError).startDate;
      end = (state as PurchaseOrdersError).endDate;
    }
    if (start != null && end != null) {
      return DateTimeRange(start: start, end: end);
    }
    return null;
  }

  int get currentPage {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).currentPage;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).currentPage;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).currentPage;
    }
    return 0;
  }

  int get totalPages {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).totalPages;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).totalPages;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).totalPages;
    }
    return 1;
  }

  int get pageSize {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).pageSize;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).pageSize;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).pageSize;
    }
    return PurchaseOrdersState.pageSize;
  }

  void loadOrders({bool reset = false}) => cubit.loadOrders(refresh: reset);
  void setSearchText(String v) => cubit.setSearchText(v);
  void setStatusFilter(String v) => cubit.setStatusFilter(v);
  void setWarehouseFilter(String v) => cubit.setWarehouseFilter(v);
  void setDateRange(DateTimeRange? v) => cubit.setDateRange(v?.start, v?.end);
  void setPage(int p) => cubit.loadOrders(page: p);
  void setPageSize(int s) => cubit.setPageSize(s);

  Future<void> updateOrderStatus(String id, String status) async {
    await cubit.updateOrderStatus(id, status);
  }
}
