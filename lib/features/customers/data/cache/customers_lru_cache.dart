import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_global_stats_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_page_entity.dart';

/// Caché L1 LRU acotada en memoria para el módulo de clientes.
///
/// Evita fugas de RAM en dispositivos de gama baja limitando el número máximo
/// de páginas, snapshots VIP y cuentas de crédito en memoria, y sobrevive a la
/// navegación entre rutas para garantizar renderizado Frame 0 (Zero-Shimmer).
@lazySingleton
class CustomersLruCache {
  static const int maxPages = 12;
  static const int maxTopEntries = 6;
  static const int maxCreditEntries = 30;

  static const Duration pageTtl = Duration(minutes: 3);
  static const Duration statsTtl = Duration(minutes: 2);
  static const Duration topTtl = Duration(minutes: 3);
  static const Duration creditTtl = Duration(minutes: 3);
  static const Duration maxStaleAge = Duration(minutes: 30);

  final LinkedHashMap<String, _CustomerPageEntry> _pages = LinkedHashMap();
  final LinkedHashMap<String, _TopCustomersEntry> _topEntries = LinkedHashMap();
  final LinkedHashMap<String, _CreditEntry> _credits = LinkedHashMap();
  _StatsEntry? _statsEntry;
  String? _latestPageKey;

  static String buildPageKey({
    String query = '',
    bool showOnlyWithDebt = false,
    int offset = 0,
    int limit = 20,
  }) {
    return '${query.trim().toLowerCase()}|$showOnlyWithDebt|$offset|$limit';
  }

  static String buildTopKey({
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final s = startDate?.toUtc().millisecondsSinceEpoch ?? 'null';
    final e = endDate?.toUtc().millisecondsSinceEpoch ?? 'null';
    return '$limit|$s|$e';
  }

  ({CustomersPageEntity data, bool isStale})? getPage({
    String query = '',
    bool showOnlyWithDebt = false,
    int offset = 0,
    int limit = 20,
  }) {
    final key = buildPageKey(
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
      offset: offset,
      limit: limit,
    );
    final entry = _pages[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.cachedAt);
    if (age > maxStaleAge) {
      _pages.remove(key);
      if (_latestPageKey == key) _latestPageKey = null;
      return null;
    }

    _pages
      ..remove(key)
      ..[key] = entry;
    _latestPageKey = key;

    return (data: entry.data, isStale: age > pageTtl);
  }

  void putPage({
    required String query,
    required bool showOnlyWithDebt,
    required int offset,
    required int limit,
    required CustomersPageEntity data,
  }) {
    final key = buildPageKey(
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
      offset: offset,
      limit: limit,
    );

    if (_pages.containsKey(key)) {
      _pages.remove(key);
    } else if (_pages.length >= maxPages) {
      final oldest = _pages.keys.first;
      _pages.remove(oldest);
      if (_latestPageKey == oldest) _latestPageKey = null;
    }

    _pages[key] = _CustomerPageEntry(data: data, cachedAt: DateTime.now());
    _latestPageKey = key;
  }

  ({CustomersGlobalStatsEntity data, bool isStale})? getStats() {
    final entry = _statsEntry;
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.cachedAt);
    if (age > maxStaleAge) {
      _statsEntry = null;
      return null;
    }
    return (data: entry.data, isStale: age > statsTtl);
  }

  void putStats(CustomersGlobalStatsEntity stats) {
    _statsEntry = _StatsEntry(data: stats, cachedAt: DateTime.now());
  }

  ({List<CustomerEntity> data, bool isStale})? getTopCustomers({
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final key = buildTopKey(
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
    final entry = _topEntries[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.cachedAt);
    if (age > maxStaleAge) {
      _topEntries.remove(key);
      return null;
    }

    _topEntries
      ..remove(key)
      ..[key] = entry;

    return (data: entry.data, isStale: age > topTtl);
  }

  void putTopCustomers({
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
    required List<CustomerEntity> data,
  }) {
    final key = buildTopKey(
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );

    if (_topEntries.containsKey(key)) {
      _topEntries.remove(key);
    } else if (_topEntries.length >= maxTopEntries) {
      _topEntries.remove(_topEntries.keys.first);
    }

    _topEntries[key] = _TopCustomersEntry(
      data: List<CustomerEntity>.unmodifiable(data),
      cachedAt: DateTime.now(),
    );
  }

  CustomerCreditEntity? getCredit(String customerId) {
    final entry = _credits[customerId];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.cachedAt) > creditTtl) {
      _credits.remove(customerId);
      return null;
    }

    _credits
      ..remove(customerId)
      ..[customerId] = entry;
    return entry.credit;
  }

  void putCredit(String customerId, CustomerCreditEntity credit) {
    if (_credits.containsKey(customerId)) {
      _credits.remove(customerId);
    } else if (_credits.length >= maxCreditEntries) {
      _credits.remove(_credits.keys.first);
    }
    _credits[customerId] = _CreditEntry(
      credit: credit,
      cachedAt: DateTime.now(),
    );
  }

  void invalidateCredit(String customerId) {
    _credits.remove(customerId);
  }

  void invalidateAll() {
    _pages.clear();
    _topEntries.clear();
    _credits.clear();
    _statsEntry = null;
    _latestPageKey = null;
  }
}

class _CustomerPageEntry {
  final CustomersPageEntity data;
  final DateTime cachedAt;
  const _CustomerPageEntry({required this.data, required this.cachedAt});
}

class _StatsEntry {
  final CustomersGlobalStatsEntity data;
  final DateTime cachedAt;
  const _StatsEntry({required this.data, required this.cachedAt});
}

class _TopCustomersEntry {
  final List<CustomerEntity> data;
  final DateTime cachedAt;
  const _TopCustomersEntry({required this.data, required this.cachedAt});
}

class _CreditEntry {
  final CustomerCreditEntity credit;
  final DateTime cachedAt;
  const _CreditEntry({required this.credit, required this.cachedAt});
}
