import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

/// Caché L1 LRU acotada en memoria para el directorio de proveedores y catálogo activo.
///
/// Sobrevive a la destrucción de Cubits/Widgets al navegar entre rutas,
/// permitiendo renderizado Frame 0 (Zero-Shimmer) y revalidación SWR.
@lazySingleton
class SuppliersLruCache {
  static const int maxPages = 20;
  static const Duration pageTtl = Duration(minutes: 3);
  static const Duration maxStaleAge = Duration(minutes: 30);
  static const Duration statsTtl = Duration(minutes: 2);
  static const Duration activeSuppliersTtl = Duration(minutes: 5);

  final LinkedHashMap<String, _SupplierPageCacheEntry> _pages = LinkedHashMap();
  final Map<String, _SupplierStatsCacheEntry> _statsByQuery = {};
  String? _latestKey;

  List<SupplierEntity>? _activeSuppliers;
  DateTime? _activeSuppliersCachedAt;

  static String buildKey({
    required int page,
    required int pageSize,
    required String searchQuery,
    required bool? filterIsActive,
  }) {
    return '${searchQuery.trim().toLowerCase()}|${filterIsActive?.toString() ?? 'all'}|$page|$pageSize';
  }

  ({SuppliersPageEntity data, bool isStale})? getPage(String key) {
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

    final cachedStats = entry.data.stats ?? getValidStats(entry.searchQuery);
    final hydrated =
        cachedStats != null
            ? entry.data.copyWith(stats: cachedStats)
            : entry.data;

    return (data: hydrated, isStale: age > pageTtl);
  }

  ({
    SuppliersPageEntity data,
    String searchQuery,
    bool? filterIsActive,
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
      filterIsActive: entry.filterIsActive,
      page: entry.page,
      pageSize: entry.pageSize,
      isStale: age > pageTtl,
    );
  }

  SupplierStatsEntity? getValidStats(String searchQuery) {
    final q = searchQuery.trim().toLowerCase();
    final entry = _statsByQuery[q];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > statsTtl) {
      _statsByQuery.remove(q);
      return null;
    }
    return entry.stats;
  }

  List<SupplierEntity>? getActiveSuppliers() {
    if (_activeSuppliers == null || _activeSuppliersCachedAt == null) {
      return null;
    }
    if (DateTime.now().difference(_activeSuppliersCachedAt!) >
        activeSuppliersTtl) {
      _activeSuppliers = null;
      _activeSuppliersCachedAt = null;
      return null;
    }
    return _activeSuppliers;
  }

  void putActiveSuppliers(List<SupplierEntity> list) {
    _activeSuppliers = List.unmodifiable(list);
    _activeSuppliersCachedAt = DateTime.now();
  }

  void putPage({
    required String key,
    required SuppliersPageEntity data,
    required String searchQuery,
    required bool? filterIsActive,
    required int page,
    required int pageSize,
  }) {
    final now = DateTime.now();
    final q = searchQuery.trim().toLowerCase();

    if (data.stats != null) {
      if (_statsByQuery.length >= 16) {
        _statsByQuery.remove(_statsByQuery.keys.first);
      }
      _statsByQuery[q] = _SupplierStatsCacheEntry(
        stats: data.stats!,
        cachedAt: now,
      );
    }

    final normalized = SuppliersPageEntity(
      suppliers: List.unmodifiable(data.suppliers),
      totalCount: data.totalCount,
      stats: data.stats ?? _statsByQuery[q]?.stats,
    );

    _pages.remove(key);
    if (_pages.length >= maxPages) {
      _pages.remove(_pages.keys.first);
    }

    _pages[key] = _SupplierPageCacheEntry(
      data: normalized,
      searchQuery: searchQuery,
      filterIsActive: filterIsActive,
      page: page,
      pageSize: pageSize,
      cachedAt: now,
    );
    _latestKey = key;
  }

  void patchSupplier(SupplierEntity updated) {
    patchSuppliers([updated]);
  }

  void patchSuppliers(List<SupplierEntity> updatedList) {
    if (updatedList.isEmpty) return;
    _activeSuppliers = null;
    _activeSuppliersCachedAt = null;

    final byId = {for (final s in updatedList) s.id: s};
    final previousById = <String, SupplierEntity>{};

    for (final key in _pages.keys.toList()) {
      final entry = _pages[key]!;
      var changed = false;
      final nextSuppliers = List<SupplierEntity>.from(entry.data.suppliers);

      for (var i = 0; i < nextSuppliers.length; i++) {
        final match = byId[nextSuppliers[i].id];
        if (match != null) {
          previousById.putIfAbsent(match.id, () => nextSuppliers[i]);
          nextSuppliers[i] = match;
          changed = true;
        }
      }

      if (!changed) continue;

      final nextStats = _recomputeStatsDelta(
        entry.data.stats,
        previousById,
        byId,
      );

      _pages[key] = _SupplierPageCacheEntry(
        data: SuppliersPageEntity(
          suppliers: List.unmodifiable(nextSuppliers),
          totalCount: entry.data.totalCount,
          stats: nextStats,
        ),
        searchQuery: entry.searchQuery,
        filterIsActive: entry.filterIsActive,
        page: entry.page,
        pageSize: entry.pageSize,
        cachedAt: entry.cachedAt,
      );
    }

    if (previousById.isNotEmpty) {
      for (final q in _statsByQuery.keys.toList()) {
        final sEntry = _statsByQuery[q]!;
        final nextStats = _recomputeStatsDelta(
          sEntry.stats,
          previousById,
          byId,
        );
        if (nextStats != null) {
          _statsByQuery[q] = _SupplierStatsCacheEntry(
            stats: nextStats,
            cachedAt: sEntry.cachedAt,
          );
        }
      }
    }
  }

  SupplierStatsEntity? _recomputeStatsDelta(
    SupplierStatsEntity? current,
    Map<String, SupplierEntity> previousById,
    Map<String, SupplierEntity> nextById,
  ) {
    if (current == null) return null;
    var activeDelta = 0;
    var inactiveDelta = 0;
    var taxDelta = 0;

    for (final entry in previousById.entries) {
      final prev = entry.value;
      final next = nextById[entry.key];
      if (next == null) continue;

      activeDelta += (next.isActive ? 1 : 0) - (prev.isActive ? 1 : 0);
      inactiveDelta += (!next.isActive ? 1 : 0) - (!prev.isActive ? 1 : 0);

      final prevHasTax = prev.taxId != null && prev.taxId!.trim().isNotEmpty;
      final nextHasTax = next.taxId != null && next.taxId!.trim().isNotEmpty;
      taxDelta += (nextHasTax ? 1 : 0) - (prevHasTax ? 1 : 0);
    }

    return current.copyWith(
      activeSuppliers: (current.activeSuppliers + activeDelta).clamp(
        0,
        1 << 30,
      ),
      inactiveSuppliers: (current.inactiveSuppliers + inactiveDelta).clamp(
        0,
        1 << 30,
      ),
      withTaxIdCount: (current.withTaxIdCount + taxDelta).clamp(0, 1 << 30),
    );
  }

  void invalidateDirectory() {
    _pages.clear();
    _statsByQuery.clear();
    _latestKey = null;
    _activeSuppliers = null;
    _activeSuppliersCachedAt = null;
  }

  void invalidateAll() => invalidateDirectory();
}

class _SupplierPageCacheEntry {
  final SuppliersPageEntity data;
  final String searchQuery;
  final bool? filterIsActive;
  final int page;
  final int pageSize;
  final DateTime cachedAt;

  const _SupplierPageCacheEntry({
    required this.data,
    required this.searchQuery,
    required this.filterIsActive,
    required this.page,
    required this.pageSize,
    required this.cachedAt,
  });
}

class _SupplierStatsCacheEntry {
  final SupplierStatsEntity stats;
  final DateTime cachedAt;

  const _SupplierStatsCacheEntry({
    required this.stats,
    required this.cachedAt,
  });
}
