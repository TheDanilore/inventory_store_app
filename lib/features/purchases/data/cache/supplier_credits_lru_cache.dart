import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

/// Caché L1 LRU acotada en memoria para cuentas de crédito de proveedores.
///
/// Sobrevive a la destrucción de Cubits y Widgets al navegar entre rutas,
/// permitiendo renderizado en Frame 0 (Zero-Shimmer) y revalidación SWR.
@lazySingleton
class SupplierCreditsLruCache {
  static const int maxPages = 20;
  static const Duration pageTtl = Duration(minutes: 3);
  static const Duration maxStaleAge = Duration(minutes: 30);
  static const Duration statsTtl = Duration(minutes: 2);

  final LinkedHashMap<String, _CreditPageCacheEntry> _pages = LinkedHashMap();
  final Map<String, _StatsCacheEntry> _statsByQuery = {};
  String? _latestKey;

  static String buildKey({
    required int page,
    required int pageSize,
    required String searchQuery,
    required bool withDebtOnly,
  }) {
    return '${searchQuery.trim().toLowerCase()}|$withDebtOnly|$page|$pageSize';
  }

  /// Retorna la página cacheada si existe dentro de [maxStaleAge].
  /// Marca [isStale] = true cuando superó [pageTtl] para revalidar vía SWR.
  ({SupplierCreditsPageEntity data, bool isStale})? getPage(String key) {
    final entry = _pages[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.cachedAt);
    if (age > maxStaleAge) {
      _pages.remove(key);
      if (_latestKey == key) _latestKey = null;
      return null;
    }

    // Política LRU: promover al final
    _pages
      ..remove(key)
      ..[key] = entry;

    final cachedStats = entry.data.stats ?? getValidStats(entry.searchQuery);
    final hydrated =
        cachedStats != null
            ? entry.data.copyWith(stats: cachedStats)
            : entry.data;

    return (data: hydrated, isStale: age > pageTtl);
  }

  /// Retorna el snapshot más reciente para hidratación instantánea en Frame 0
  /// al volver a la pantalla.
  ({
    SupplierCreditsPageEntity data,
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

    final cachedStats = entry.data.stats ?? getValidStats(entry.searchQuery);
    final hydrated =
        cachedStats != null
            ? entry.data.copyWith(stats: cachedStats)
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

  SupplierCreditStatsEntity? getValidStats(String searchQuery) {
    final q = searchQuery.trim().toLowerCase();
    final entry = _statsByQuery[q];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > statsTtl) {
      _statsByQuery.remove(q);
      return null;
    }
    return entry.stats;
  }

  void putPage({
    required String key,
    required SupplierCreditsPageEntity data,
    required String searchQuery,
    required bool withDebtOnly,
    required int page,
    required int pageSize,
  }) {
    final now = DateTime.now();
    final q = searchQuery.trim().toLowerCase();

    if (data.stats != null) {
      if (_statsByQuery.length >= 16) {
        _statsByQuery.remove(_statsByQuery.keys.first);
      }
      _statsByQuery[q] = _StatsCacheEntry(stats: data.stats!, cachedAt: now);
    }

    final normalizedPage = SupplierCreditsPageEntity(
      accounts: List.unmodifiable(data.accounts),
      totalCount: data.totalCount,
      stats: data.stats ?? _statsByQuery[q]?.stats,
    );

    _pages.remove(key);
    if (_pages.length >= maxPages) {
      _pages.remove(_pages.keys.first);
    }

    _pages[key] = _CreditPageCacheEntry(
      data: normalizedPage,
      searchQuery: searchQuery,
      withDebtOnly: withDebtOnly,
      page: page,
      pageSize: pageSize,
      cachedAt: now,
    );
    _latestKey = key;
  }

  /// Actualiza una cuenta en todas las páginas cacheadas sin purgar la caché
  /// (Patch-in-Place), evitando parpadeos de Shimmer tras pagos o ediciones.
  void patchCredit(SupplierCreditEntity updated) {
    SupplierCreditEntity? previous;

    for (final key in _pages.keys.toList()) {
      final entry = _pages[key]!;
      final idx = entry.data.accounts.indexWhere(
        (a) => a.creditId == updated.creditId,
      );
      if (idx == -1) continue;

      previous ??= entry.data.accounts[idx];
      final nextAccounts = List<SupplierCreditEntity>.from(entry.data.accounts);
      nextAccounts[idx] = updated;

      final nextStats = _recomputeStatsDelta(
        entry.data.stats,
        previous,
        updated,
      );

      _pages[key] = _CreditPageCacheEntry(
        data: SupplierCreditsPageEntity(
          accounts: List.unmodifiable(nextAccounts),
          totalCount: entry.data.totalCount,
          stats: nextStats,
        ),
        searchQuery: entry.searchQuery,
        withDebtOnly: entry.withDebtOnly,
        page: entry.page,
        pageSize: entry.pageSize,
        cachedAt: entry.cachedAt,
      );
    }

    if (previous != null) {
      for (final q in _statsByQuery.keys.toList()) {
        final sEntry = _statsByQuery[q]!;
        final patched = _recomputeStatsDelta(sEntry.stats, previous, updated);
        if (patched != null) {
          _statsByQuery[q] = _StatsCacheEntry(
            stats: patched,
            cachedAt: sEntry.cachedAt,
          );
        }
      }
    }
  }

  SupplierCreditStatsEntity? _recomputeStatsDelta(
    SupplierCreditStatsEntity? current,
    SupplierCreditEntity prev,
    SupplierCreditEntity next,
  ) {
    if (current == null) return null;

    final debtDelta = next.currentDebt - prev.currentDebt;
    final activeDelta =
        (next.isActive ? 1 : 0) - (prev.isActive ? 1 : 0);
    final suspendedDelta =
        (!next.isActive ? 1 : 0) - (!prev.isActive ? 1 : 0);

    final prevMaxed = prev.isActive && prev.isMaxedOut;
    final nextMaxed = next.isActive && next.isMaxedOut;
    final maxedDelta = (nextMaxed ? 1 : 0) - (prevMaxed ? 1 : 0);

    final prevHasDebt = prev.isActive && prev.currentDebt > 0;
    final nextHasDebt = next.isActive && next.currentDebt > 0;
    final debtCountDelta = (nextHasDebt ? 1 : 0) - (prevHasDebt ? 1 : 0);

    return SupplierCreditStatsEntity(
      totalDebt: (current.totalDebt + debtDelta).clamp(0.0, double.infinity),
      activeAccounts: (current.activeAccounts + activeDelta).clamp(0, 1 << 30),
      suspendedAccounts: (current.suspendedAccounts + suspendedDelta).clamp(
        0,
        1 << 30,
      ),
      maxedOutAccounts: (current.maxedOutAccounts + maxedDelta).clamp(
        0,
        1 << 30,
      ),
      debtCount: (current.debtCount + debtCountDelta).clamp(0, 1 << 30),
    );
  }

  void invalidateAll() {
    _pages.clear();
    _statsByQuery.clear();
    _latestKey = null;
  }
}

class _CreditPageCacheEntry {
  final SupplierCreditsPageEntity data;
  final String searchQuery;
  final bool withDebtOnly;
  final int page;
  final int pageSize;
  final DateTime cachedAt;

  const _CreditPageCacheEntry({
    required this.data,
    required this.searchQuery,
    required this.withDebtOnly,
    required this.page,
    required this.pageSize,
    required this.cachedAt,
  });
}

class _StatsCacheEntry {
  final SupplierCreditStatsEntity stats;
  final DateTime cachedAt;

  const _StatsCacheEntry({
    required this.stats,
    required this.cachedAt,
  });
}
