import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';

class _OrdersCacheEntry {
  final List<OrderEntity> orders;
  final int total;
  final DateTime timestamp;

  _OrdersCacheEntry({
    required this.orders,
    required this.total,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 3);
}

class _FinancialAccountsCacheEntry {
  final List<Map<String, dynamic>> accounts;
  final DateTime timestamp;

  _FinancialAccountsCacheEntry({
    required this.accounts,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 15);
}

class _OrderDetailCacheEntry {
  final OrderEntity order;
  final DateTime timestamp;

  _OrderDetailCacheEntry({required this.order, required this.timestamp});

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}

class _OrderItemsCacheEntry {
  final List<OrderItemEntity> items;
  final DateTime timestamp;

  _OrderItemsCacheEntry({required this.items, required this.timestamp});

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}

/// Gestor de caché L1 en memoria para pedidos con política Stale-While-Revalidate (SWR)
/// e invalidaciones quirúrgicas in-situ (evita wipeouts destructivos).
@lazySingleton
class OrdersCacheManager {
  static const int maxOrdersCacheEntries = 30;

  final Map<String, _OrdersCacheEntry> _ordersCache = {};
  final Map<String, _OrderDetailCacheEntry> _orderByIdCache = {};
  final Map<String, _OrderItemsCacheEntry> _orderItemsCache = {};
  _FinancialAccountsCacheEntry? _accountsCache;

  static String buildFilteredOrdersKey({
    String? customerIdFilter,
    required String statusFilter,
    required String paymentStatusFilter,
    String? warehouseFilter,
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
    required int limit,
    required int offset,
  }) {
    return '${customerIdFilter ?? ""}_${statusFilter}_${paymentStatusFilter}_${warehouseFilter ?? ""}_${startDate?.millisecondsSinceEpoch ?? ""}_${endDate?.millisecondsSinceEpoch ?? ""}_${searchQuery.trim().toLowerCase()}_${limit}_$offset';
  }

  ({List<OrderEntity> orders, int total})? getCachedFilteredOrders({
    String? customerIdFilter,
    required String statusFilter,
    required String paymentStatusFilter,
    String? warehouseFilter,
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
    required int limit,
    required int offset,
  }) {
    final key = buildFilteredOrdersKey(
      customerIdFilter: customerIdFilter,
      statusFilter: statusFilter,
      paymentStatusFilter: paymentStatusFilter,
      warehouseFilter: warehouseFilter,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
    final cached = _ordersCache[key];
    if (cached != null && !cached.isExpired) {
      return (orders: cached.orders, total: cached.total);
    }
    return null;
  }

  void cacheFilteredOrders(String key, List<OrderEntity> orders, int total) {
    if (_ordersCache.length >= maxOrdersCacheEntries) {
      _ordersCache.remove(_ordersCache.keys.first);
    }
    _ordersCache[key] = _OrdersCacheEntry(
      orders: orders,
      total: total,
      timestamp: DateTime.now(),
    );
  }

  OrderEntity? getCachedOrder(String orderId) {
    final entry = _orderByIdCache[orderId];
    if (entry != null && !entry.isExpired) {
      return entry.order;
    }
    return null;
  }

  void cacheOrder(OrderEntity order) {
    _orderByIdCache[order.id] = _OrderDetailCacheEntry(
      order: order,
      timestamp: DateTime.now(),
    );
  }

  List<OrderItemEntity>? getCachedOrderItems(String orderId) {
    final entry = _orderItemsCache[orderId];
    if (entry != null && !entry.isExpired) {
      return entry.items;
    }
    return null;
  }

  void cacheOrderItems(String orderId, List<OrderItemEntity> items) {
    _orderItemsCache[orderId] = _OrderItemsCacheEntry(
      items: items,
      timestamp: DateTime.now(),
    );
  }

  List<Map<String, dynamic>>? getCachedFinancialAccounts({
    bool forceRefresh = false,
  }) {
    if (!forceRefresh && _accountsCache != null && !_accountsCache!.isExpired) {
      return _accountsCache!.accounts;
    }
    return null;
  }

  void cacheFinancialAccounts(List<Map<String, dynamic>> accounts) {
    _accountsCache = _FinancialAccountsCacheEntry(
      accounts: accounts,
      timestamp: DateTime.now(),
    );
  }

  /// Actualización quirúrgica in-situ: actualiza los datos de la orden en todas
  /// las páginas cacheadas y en el detalle sin borrar la colección L1.
  void updateOrderInCache(OrderEntity updatedOrder) {
    _orderByIdCache[updatedOrder.id] = _OrderDetailCacheEntry(
      order: updatedOrder,
      timestamp: DateTime.now(),
    );
    for (final entry in _ordersCache.values) {
      final index = entry.orders.indexWhere((o) => o.id == updatedOrder.id);
      if (index != -1) {
        entry.orders[index] = updatedOrder;
      }
    }
  }

  /// Actualiza únicamente el estado de la orden en caché L1 in-situ.
  void updateOrderStatusInCache(String orderId, String newStatus) {
    final cached = _orderByIdCache[orderId];
    if (cached != null) {
      _orderByIdCache[orderId] = _OrderDetailCacheEntry(
        order: cached.order.copyWith(status: newStatus),
        timestamp: DateTime.now(),
      );
    }
    for (final entry in _ordersCache.values) {
      final index = entry.orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        entry.orders[index] = entry.orders[index].copyWith(status: newStatus);
      }
    }
  }

  /// Desaloja los ítems cacheados de un pedido.
  void evictOrderItems(String orderId) {
    _orderItemsCache.remove(orderId);
  }

  /// Desaloja un pedido específico de todas las memorias.
  void evictOrder(String orderId) {
    _orderByIdCache.remove(orderId);
    _orderItemsCache.remove(orderId);
    for (final entry in _ordersCache.values) {
      entry.orders.removeWhere((o) => o.id == orderId);
    }
  }

  /// Invalida toda la caché L1 (solo en logout o recarga forzada total).
  void clearAll() {
    _ordersCache.clear();
    _orderByIdCache.clear();
    _orderItemsCache.clear();
    _accountsCache = null;
  }
}
