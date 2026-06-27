import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/services/admin/orders_service.dart';
import 'package:inventory_store_app/services/admin/order_pdf_generator.dart';

class OrdersProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  static const int pageSize = 8;

  List<OrderModel> _orders = [];
  int _totalRecords = 0;
  bool _isLoading = false;
  bool _isBackgroundLoading = false;
  String _errorMessage = '';

  final _ordersService = OrdersService();
  final Set<String> _processingOrders = {};
  String? _generatingPdfOrderId;

  // Filtros
  String _statusFilter = 'ALL';
  String _paymentStatusFilter = 'ALL';
  DateTimeRange? _dateRange;
  String _searchQuery = '';
  int _currentPage = 0;

  final String? customerIdFilter;

  OrdersProvider({this.customerIdFilter});

  // Getters
  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isBackgroundLoading => _isBackgroundLoading;
  String get errorMessage => _errorMessage;

  bool isOrderProcessing(String id) => _processingOrders.contains(id);
  bool isGeneratingPDF(String id) => _generatingPdfOrderId == id;

  int get currentPage => _currentPage;
  int get totalPages =>
      _totalRecords == 0 ? 1 : (_totalRecords / pageSize).ceil();
  int get totalRecords => _totalRecords;

  String get statusFilter => _statusFilter;
  String get paymentStatusFilter => _paymentStatusFilter;
  DateTimeRange? get dateRange => _dateRange;
  String get searchQuery => _searchQuery;

  // Totales de la página actual para el Resumen
  double get totalAmountCurrentPage =>
      _orders.fold(0, (sum, order) => sum + order.totalAmount);
  int get pendingCountCurrentPage =>
      _orders.where((o) => o.status == 'PENDING').length;

  Future<void> loadOrders({bool reset = false, bool background = false}) async {
    if (reset) {
      _currentPage = 0;
      _orders = [];
      _totalRecords = 0;
    }

    if (background) {
      _isBackgroundLoading = true;
    } else {
      _isLoading = true;
    }
    _errorMessage = '';
    notifyListeners();

    try {
      var query = _supabase.from('orders').select('''
        id,
        customer_id,
        customer_name,
        total_amount,
        total_profit,
        discount_amount,
        payment_method,
        payment_status,
        amount_paid,
        status,
        due_date,
        points_used,
        points_earned,
        created_at,
        warehouse_id,
        created_by,
        profiles!orders_customer_id_fkey ( id, full_name, phone ),
        warehouses ( id, name )
      ''');

      if (_statusFilter != 'ALL') query = query.eq('status', _statusFilter);
      if (_paymentStatusFilter != 'ALL') {
        query = query.eq('payment_status', _paymentStatusFilter);
      }
      
      if (customerIdFilter != null) {
        query = query.eq('customer_id', customerIdFilter!);
      }

      if (_dateRange != null) {
        final start = _dateRange!.start.toIso8601String();
        final end =
            _dateRange!.end
                .add(const Duration(hours: 23, minutes: 59, seconds: 59))
                .toIso8601String();
        query = query.gte('created_at', start).lte('created_at', end);
      }

      // Búsqueda a nivel de base de datos
      final queryText = _searchQuery.trim().toLowerCase();
      if (queryText.isNotEmpty) {
        final profilesResp = await _supabase
            .from('profiles')
            .select('id')
            .ilike('full_name', '%$queryText%');
        final matchingProfileIds =
            (profilesResp as List).map((e) => e['id']).toList();

        if (matchingProfileIds.isNotEmpty) {
          final idsString = matchingProfileIds.join(',');
          query = query.or(
            'customer_name.ilike.%$queryText%,id.ilike.%$queryText%,customer_id.in.($idsString)',
          );
        } else {
          query = query.or(
            'customer_name.ilike.%$queryText%,id.ilike.%$queryText%',
          );
        }
      }

      // Paginación del Servidor
      final startRow = _currentPage * pageSize;
      final endRow = startRow + pageSize - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(startRow, endRow)
          .count(CountOption.exact);

      final rawData = response.data as List<dynamic>;
      _totalRecords = response.count;
      _orders = rawData.map((e) => OrderModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading orders: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Error al cargar pedidos.';
      }
    } finally {
      _isLoading = false;
      _isBackgroundLoading = false;
      notifyListeners();
    }
  }

  void goToPage(int page) {
    if (page < 0 || page >= totalPages || page == _currentPage) return;
    _currentPage = page;
    loadOrders();
  }

  void setStatusFilter(String val) {
    if (_statusFilter == val) return;
    _statusFilter = val;
    loadOrders(reset: true);
  }

  void setPaymentStatusFilter(String val) {
    if (_paymentStatusFilter == val) return;
    _paymentStatusFilter = val;
    loadOrders(reset: true);
  }

  void setDateRange(DateTimeRange? val) {
    _dateRange = val;
    loadOrders(reset: true);
  }

  void setSearchQuery(String val) {
    if (_searchQuery == val) return;
    _searchQuery = val;
    loadOrders(reset: true);
  }

  Future<void> updateOrderStatus(OrderModel order, String newStatus) async {
    if (_processingOrders.contains(order.id)) return;
    _processingOrders.add(order.id);
    notifyListeners();

    try {
      if (newStatus == 'COMPLETED' && order.status == 'PENDING') {
        final orderData =
            await _supabase
                .from('orders')
                .select('warehouse_id')
                .eq('id', order.id)
                .single();

        await _ordersService.completeOrder(
          order: orderData,
          orderId: order.id,
          paymentMethod: order.paymentMethod,
          totalAmount: order.totalAmount,
          customerId: order.customerId,
          pointsUsed: order.pointsUsed,
          pointsEarned: order.pointsEarned,
        );
      } else if (newStatus == 'CANCELLED' || newStatus == 'RETURNED') {
        await _ordersService.cancelOrder(
          orderId: order.id,
          customerId: order.customerId,
        );
      } else {
        await _supabase
            .from('orders')
            .update({'status': newStatus})
            .eq('id', order.id);
      }
      loadOrders(background: true);
    } finally {
      _processingOrders.remove(order.id);
      notifyListeners();
    }
  }

  Future<void> generatePdfTicket(OrderModel order) async {
    if (_generatingPdfOrderId != null) return;
    _generatingPdfOrderId = order.id;
    notifyListeners();

    try {
      final rawItems = await _ordersService.fetchOrderItemsForPdf(order.id);
      final items =
          rawItems.map((row) {
            return OrderItemModel.fromJson(Map<String, dynamic>.from(row));
          }).toList();

      await OrderPdfGenerator.shareTicket(order, items: items);
    } finally {
      _generatingPdfOrderId = null;
      notifyListeners();
    }
  }
}
