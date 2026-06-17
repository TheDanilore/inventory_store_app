import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/models/order_item_model.dart';
import 'package:inventory_store_app/models/product_model.dart';

class CustomerOrdersProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  static const _kCacheKey = 'customer_orders_cache';
  static const _kCacheProfileKey = 'customer_orders_profile_cache';
  static const int _limit = 15;

  List<OrderModel> _orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isBackgroundLoading = false;

  String _statusFilter = 'ALL';
  String _searchQuery = '';
  String? _profileId;
  String _errorMessage = '';

  // Controladores de estado por pedido para evitar dobles clics
  final Map<String, bool> _processingOrders = {};

  // Getters
  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isBackgroundLoading => _isBackgroundLoading;
  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  String? get profileId => _profileId;
  String get errorMessage => _errorMessage;

  bool isOrderProcessing(String orderId) => _processingOrders[orderId] == true;

  Future<void> init() async {
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final profile =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();

      _profileId = profile?['id'] as String?;
      if (_profileId == null) {
        _orders = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Cargar de caché para UX rápido
      final cached = await _loadFromCache(_profileId!);
      if (cached != null && cached.isNotEmpty) {
        _orders = cached;
        _isLoading = false;
        _isBackgroundLoading = true;
        notifyListeners();
      }

      // Traer fresco
      await fetchOrders(reset: true);
    } catch (e) {
      _errorMessage = 'Error al inicializar: $e';
      if (_orders.isEmpty) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchOrders({bool reset = false}) async {
    if (_profileId == null) return;

    if (reset) {
      if (_orders.isEmpty) _isLoading = true;
      _hasMore = true;
      notifyListeners();
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    final offset = reset ? 0 : _orders.length;

    try {
      var query = _supabase
          .from('orders')
          .select(
            'id, customer_id, customer_name, total_amount, total_profit, payment_method, status, payment_status, amount_paid, discount_amount, created_at, warehouse_id, points_used, points_earned, profiles!orders_customer_id_fkey(full_name, phone), warehouses(name)',
          )
          .eq('customer_id', _profileId!);

      // Filtro de búsqueda (usualmente ID del pedido para clientes)
      if (_searchQuery.trim().isNotEmpty) {
        query = query.ilike('id', '%${_searchQuery.trim()}%');
      }

      // Filtro de estado
      if (_statusFilter == 'PENDING') {
        query = query.inFilter('status', ['PENDING', 'PAID']);
      } else if (_statusFilter != 'ALL') {
        query = query.eq('status', _statusFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + _limit - 1);

      final fetchedOrders =
          List<Map<String, dynamic>>.from(
            response,
          ).map(OrderModel.fromJson).toList();

      if (reset) {
        _orders = fetchedOrders;
        if (_searchQuery.isEmpty && _statusFilter == 'ALL') {
          await _saveToCache(_profileId!, fetchedOrders);
        }
      } else {
        _orders.addAll(fetchedOrders);
      }

      _hasMore = fetchedOrders.length == _limit;
      _errorMessage = '';
    } catch (e) {
      debugPrint('Error al obtener pedidos: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('clientexception')) {
        _errorMessage = 'Sin conexión a internet.';
      } else {
        _errorMessage = 'Ocurrió un error inesperado al cargar tus pedidos.';
      }
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      _isBackgroundLoading = false;
      notifyListeners();
    }
  }

  Future<List<OrderItemModel>> fetchOrderItems(String orderId) async {
    _setOrderProcessing(orderId, true);
    try {
      // Uso de !inner para evitar traer items vacíos si hubiese un filtrado en tablas relacionales,
      // aunque aquí traemos por order_id. Especificamos solo las columnas necesarias.
      final response = await _supabase
          .from('order_items')
          .select('''
            id, order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit, created_at, 
            products!inner(name, product_images(id, image_url, is_main, display_order, variant_id)), 
            product_variants(sku, product_images(id, image_url, is_main, display_order), variant_attribute_values(attribute_values(id, value, attributes(id, name))))
          ''')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(
        response,
      ).map(OrderItemModel.fromJson).toList();
    } catch (e) {
      throw Exception('Error al cargar detalle del pedido: $e');
    } finally {
      _setOrderProcessing(orderId, false);
    }
  }

  Future<ProductModel?> fetchProductDetailWithStock(String productId) async {
    try {
      final response =
          await _supabase
              .from('products')
              .select(
                'id, name, description, category_id, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, product_images(*)',
              )
              .eq('id', productId)
              .maybeSingle();

      if (response == null) return null;

      // Calcular stock sumando los lotes
      final stockResponse = await _supabase
          .from('warehouse_stock_batches')
          .select('available_quantity')
          .eq('product_id', productId)
          .gt('available_quantity', 0); // Filtro en servidor (gt 0)

      final totalStock = List<Map<String, dynamic>>.from(
        stockResponse,
      ).fold<int>(
        0,
        (sum, row) => sum + ((row['available_quantity'] as num?)?.toInt() ?? 0),
      );

      return ProductModel.fromJson(
        Map<String, dynamic>.from(response),
      ).copyWith(totalStock: totalStock);
    } catch (e) {
      throw Exception('Error al cargar producto: $e');
    }
  }

  void setStatusFilter(String filter) {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    fetchOrders(reset: true);
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    fetchOrders(reset: true);
  }

  void _setOrderProcessing(String orderId, bool isProcessing) {
    if (isProcessing) {
      _processingOrders[orderId] = true;
    } else {
      _processingOrders.remove(orderId);
    }
    notifyListeners();
  }

  // ─── Cache helpers ────────────────────────────────────────────────────────
  Future<void> _saveToCache(String profileId, List<OrderModel> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = orders.map((o) => o.toJson()).toList();
      await prefs.setString(_kCacheKey, jsonEncode(data));
      await prefs.setString(_kCacheProfileKey, profileId);
    } catch (_) {}
  }

  Future<List<OrderModel>?> _loadFromCache(String profileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedProfile = prefs.getString(_kCacheProfileKey);
      if (cachedProfile != profileId) return null;
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return null;
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCacheKey);
      await prefs.remove(_kCacheProfileKey);
    } catch (_) {}
  }
}
