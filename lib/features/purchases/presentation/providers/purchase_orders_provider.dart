import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_item_model.dart';
import 'package:inventory_store_app/features/purchases/data/repositories/purchase_orders_service.dart';

class PurchaseOrdersProvider extends ChangeNotifier {
  final PurchaseOrdersService _service = PurchaseOrdersService();

  List<PurchaseOrderModel> _orders = [];
  List<PurchaseOrderModel> get orders => _orders;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Pagination & Filters
  static const int pageSize = 8;
  int _currentPage = 0;
  int _totalRecords = 0;

  int get currentPage => _currentPage;
  int get totalPages => (_totalRecords / pageSize).ceil();

  String _searchText = '';
  String get searchText => _searchText;

  String _statusFilter = 'Todos';
  String get statusFilter => _statusFilter;

  DateTimeRange? _dateRange;
  DateTimeRange? get dateRange => _dateRange;

  // Calculated properties
  double get totalAmountFiltered =>
      _orders.fold(0, (sum, po) => sum + po.totalAmount);
  int get pendingCountFiltered =>
      _orders.where((po) => po.status == 'PENDING').length;

  Future<void> loadOrders({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _orders = [];
      _hasMore = true;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _service.fetchOrders(
        page: _currentPage,
        pageSize: pageSize,
        searchText: _searchText,
        statusFilter: _statusFilter,
        dateRange: _dateRange,
      );

      _orders = result['data'] as List<PurchaseOrderModel>;
      _totalRecords = result['count'] as int;
      _hasMore =
          false; // Ya no usamos _hasMore de forma clasica, pero lo dejo por retrocompatibilidad si es necesario, o _currentPage < totalPages - 1
    } catch (e) {
      debugPrint('Error loading purchase orders: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar órdenes de compra.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> nextPage() async {
    if (_currentPage < totalPages - 1 && !_isLoading) {
      _currentPage++;
      await loadOrders();
    }
  }

  Future<void> previousPage() async {
    if (_currentPage > 0 && !_isLoading) {
      _currentPage--;
      await loadOrders();
    }
  }

  void goToPage(int page) {
    if (page < 0 || page >= totalPages || page == _currentPage) return;
    _currentPage = page;
    loadOrders();
  }

  void setSearchText(String text) {
    _searchText = text;
    loadOrders(reset: true);
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    loadOrders(reset: true);
  }

  void setDateRange(DateTimeRange? range) {
    _dateRange = range;
    loadOrders(reset: true);
  }

  Future<List<PurchaseOrderItemModel>> loadItemsForOrder(String poId) async {
    return await _service.fetchOrderItems(poId);
  }

  Future<void> updateOrderStatus(String poId, String status) async {
    await _service.updateOrderStatus(poId, status);
    // Reload to refresh status locally
    await loadOrders();
  }
}
