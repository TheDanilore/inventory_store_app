import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_list_result_entity.dart';

/// Caché L1 LRU acotada en memoria para cuentas por cobrar de clientes.
///
/// Sobrevive a la destrucción de Cubits y Widgets al navegar entre rutas,
/// permitiendo renderizado Frame 0 (Zero-Shimmer) y revalidación SWR.
@lazySingleton
class CustomerCreditsLruCache {
  static const int maxPages = 15;
  static const Duration pageTtl = Duration(minutes: 3);
  static const Duration statsTtl = Duration(minutes: 2);
  static const Duration maxStaleAge = Duration(minutes: 30);

  final LinkedHashMap<String, _CustomerCreditPageEntry> _pages = LinkedHashMap();
  final Map<String, _StatsEntry> _statsByQuery = {};
  String? _latestKey;

  static String buildKey({
    required int page,
    required int pageSize,
    required String searchQuery,
    required bool withDebtOnly,
  }) {
    return '${searchQuery.trim().toLowerCase()}|$withDebtOnly|$page|$pageSize';
  }

  ({CustomerCreditListResultEntity data, bool isStale})? getPage(String key) {
    final entry = _pages[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.cachedAt);
    if (age > maxStaleAge) {
      _pages.remove(key);
      if (_latestKey == key) _latestKey = null;
      return null;
    }

    _pages
      ..remove(key)
      ..[key] = entry;
    _latestKey = key;

    final freshStats = _getValidStats(entry.searchQuery);
    final hydrated =
        freshStats != null
            ? entry.data.copyWith(
              totalDebt: freshStats.totalDebt,
              activeAccounts: freshStats.activeAccounts,
              suspendedAccounts: freshStats.suspendedAccounts,
              maxedOutAccounts: freshStats.maxedOutAccounts,
              debtCount: freshStats.debtCount,
            )
            : entry.data;

    return (data: hydrated, isStale: age > pageTtl);
  }

  ({
    CustomerCreditListResultEntity data,
    String searchQuery,
    bool withDebtOnly,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestSnapshot() {
    if (_pages.isEmpty) return null;
    final key =
        (_latestKey != null && _pages.containsKey(_latestKey))
            ? _latestKey!
            : _pages.keys.last;
    final entry = _pages[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.cachedAt);
    if (age > maxStaleAge) {
      _pages.remove(key);
      if (_latestKey == key) _latestKey = null;
      return null;
    }

    final freshStats = _getValidStats(entry.searchQuery);
    final hydrated =
        freshStats != null
            ? entry.data.copyWith(
              totalDebt: freshStats.totalDebt,
              activeAccounts: freshStats.activeAccounts,
              suspendedAccounts: freshStats.suspendedAccounts,
              maxedOutAccounts: freshStats.maxedOutAccounts,
              debtCount: freshStats.debtCount,
            )
            : entry.data;

    return (
      data: hydrated,
      searchQuery: entry.searchQuery,
      withDebtOnly: entry.withDebtOnly,
      page: entry.page,
      pageSize: entry.pageSize,
      isStale: age > pageTtl,
    );
  }

  _StatsEntry? _getValidStats(String searchQuery) {
    final q = searchQuery.trim().toLowerCase();
    final entry = _statsByQuery[q];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > statsTtl) {
      _statsByQuery.remove(q);
      return null;
    }
    return entry;
  }

  void putPage({
    required String key,
    required CustomerCreditListResultEntity data,
    required String searchQuery,
    required bool withDebtOnly,
    required int page,
    required int pageSize,
  }) {
    final now = DateTime.now();
    final q = searchQuery.trim().toLowerCase();

    _statsByQuery[q] = _StatsEntry(
      totalDebt: data.totalDebt,
      activeAccounts: data.activeAccounts,
      suspendedAccounts: data.suspendedAccounts,
      maxedOutAccounts: data.maxedOutAccounts,
      debtCount: data.debtCount,
      cachedAt: now,
    );

    if (_pages.containsKey(key)) {
      _pages.remove(key);
    } else if (_pages.length >= maxPages) {
      final oldest = _pages.keys.first;
      _pages.remove(oldest);
      if (_latestKey == oldest) _latestKey = null;
    }

    _pages[key] = _CustomerCreditPageEntry(
      data: data,
      searchQuery: searchQuery,
      withDebtOnly: withDebtOnly,
      page: page,
      pageSize: pageSize,
      cachedAt: now,
    );
    _latestKey = key;
  }

  /// Actualiza puntualmente una cuenta en caché tras toggle/límite sin esperar otro RTT.
  void patchAccount(CustomerCreditEntity updated) {
    final now = DateTime.now();
    for (final key in _pages.keys.toList()) {
      final entry = _pages[key]!;
      final idx = entry.data.accounts.indexWhere((a) => a.id == updated.id);
      if (idx == -1) continue;

      final nextAccounts = List<CustomerCreditEntity>.from(
        entry.data.accounts,
      );
      final previous = nextAccounts[idx];
      nextAccounts[idx] = updated;

      int activeDelta = 0;
      int suspendedDelta = 0;
      if (previous.isActive != updated.isActive) {
        activeDelta = updated.isActive ? 1 : -1;
        suspendedDelta = updated.isActive ? -1 : 1;
      }

      _pages[key] = _CustomerCreditPageEntry(
        data: entry.data.copyWith(
          accounts: nextAccounts,
          activeAccounts: (entry.data.activeAccounts + activeDelta).clamp(
            0,
            999999,
          ),
          suspendedAccounts: (entry.data.suspendedAccounts + suspendedDelta)
              .clamp(0, 999999),
        ),
        searchQuery: entry.searchQuery,
        withDebtOnly: entry.withDebtOnly,
        page: entry.page,
        pageSize: entry.pageSize,
        cachedAt: now,
      );
    }
    _statsByQuery.clear();
  }

  void invalidateAll() {
    _pages.clear();
    _statsByQuery.clear();
    _latestKey = null;
  }
}

class _CustomerCreditPageEntry {
  final CustomerCreditListResultEntity data;
  final String searchQuery;
  final bool withDebtOnly;
  final int page;
  final int pageSize;
  final DateTime cachedAt;

  const _CustomerCreditPageEntry({
    required this.data,
    required this.searchQuery,
    required this.withDebtOnly,
    required this.page,
    required this.pageSize,
    required this.cachedAt,
  });
}

class _StatsEntry {
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;
  final int debtCount;
  final DateTime cachedAt;

  const _StatsEntry({
    required this.totalDebt,
    required this.activeAccounts,
    required this.suspendedAccounts,
    required this.maxedOutAccounts,
    required this.debtCount,
    required this.cachedAt,
  });
}
