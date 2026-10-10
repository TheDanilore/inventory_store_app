import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/domain/repositories/dashboard_repository.dart';

class _DashboardCacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _DashboardCacheEntry({required this.data, required this.timestamp});

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 3);
}

@LazySingleton(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  final SupabaseClient _supabase;

  _DashboardCacheEntry<InventoryMetricsEntity>? _inventoryCache;
  final Map<String, _DashboardCacheEntry<SalesMetricsEntity>> _salesCache = {};
  final Map<String, _DashboardCacheEntry<List<Map<String, dynamic>>>> _batchesCache =
      {};

  DashboardRepositoryImpl(this._supabase);

  @override
  Future<Either<Failure, InventoryMetricsEntity>> getInventoryMetrics({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _inventoryCache != null && !_inventoryCache!.isExpired) {
      return right(_inventoryCache!.data);
    }

    try {
      final response = await _supabase
          .from('products')
          .select('''
            id, name, is_active, stock_control,
            product_variants(id, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active),
            warehouse_stock_batches(variant_id, available_quantity)
          ''')
          .eq('is_active', true);

      final products = List<Map<String, dynamic>>.from(response);

      int totalStock = 0;
      double totalInvestment = 0.0;
      double retailValue = 0.0;
      double expectedMaxProfit = 0.0;
      double expectedMinProfit = 0.0;
      double grossProfit = 0.0;
      int lowStockProducts = 0;
      int totalProducts = 0;

      for (var row in products) {
        final stockControl = row['stock_control'] as bool? ?? true;
        final prodUnitCost = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
        final prodSalePrice = (row['sale_price'] as num?)?.toDouble() ?? 0.0;
        final prodWholesalePrice = (row['wholesale_price'] as num?)?.toDouble();
        final prodWholesaleMinQty =
            (row['wholesale_min_quantity'] as num?)?.toInt() ?? 3;

        final variants = List<Map<String, dynamic>>.from(
          row['product_variants'] ?? [],
        );
        final activeVariants =
            variants.where((v) => v['is_active'] == true).toList();

        totalProducts++;

        final batches = List<Map<String, dynamic>>.from(
          row['warehouse_stock_batches'] ?? [],
        );

        for (final variant in activeVariants) {
          final variantId = variant['id'] as String?;
          if (variantId == null) continue;

          final variantStock = batches
              .where((b) => b['variant_id'] == variantId)
              .fold<int>(
                0,
                (s, b) => s + ((b['available_quantity'] as num?)?.toInt() ?? 0),
              );

          final reorderPoint = (variant['reorder_point'] as num?)?.toInt() ?? 3;

          if (stockControl && variantStock <= reorderPoint) {
            lowStockProducts++;
          }

          if (variantStock <= 0) continue;

          final varUnitCost =
              ((variant['unit_cost'] as num?)?.toDouble() ?? 0) > 0
                  ? (variant['unit_cost'] as num).toDouble()
                  : prodUnitCost;

          final rawVarSalePrice =
              (variant['sale_price'] as num?)?.toDouble() ?? 0.0;
          final varSalePrice =
              rawVarSalePrice > 0 ? rawVarSalePrice : prodSalePrice;

          final rawVarWholesalePrice =
              (variant['wholesale_price'] as num?)?.toDouble() ?? 0.0;
          final varWholesalePrice =
              rawVarWholesalePrice > 0
                  ? rawVarWholesalePrice
                  : prodWholesalePrice;
          final varWholesaleMinQty =
              (variant['wholesale_min_quantity'] as num?)?.toInt() ??
              prodWholesaleMinQty;

          if (stockControl) {
            totalStock += variantStock;
          }

          totalInvestment += variantStock * varUnitCost;
          retailValue += variantStock * varSalePrice;

          grossProfit +=
              (variantStock * varSalePrice) - (variantStock * varUnitCost);
          expectedMaxProfit +=
              (variantStock * varSalePrice) - (variantStock * varUnitCost);

          final canApplyWholesale =
              varWholesalePrice != null && variantStock >= varWholesaleMinQty;
          final effectiveWholesale =
              canApplyWholesale ? varWholesalePrice : varSalePrice;
          expectedMinProfit +=
              (variantStock * effectiveWholesale) -
              (variantStock * varUnitCost);
        }
      }

      final grossMargin =
          totalInvestment > 0 ? (grossProfit / retailValue) * 100 : 0.0;

      final inventoryEntity = InventoryMetricsEntity(
        totalStock: totalStock,
        lowStockProducts: lowStockProducts,
        totalInvestment: totalInvestment,
        retailValue: retailValue,
        grossProfit: grossProfit,
        expectedMaxProfit: expectedMaxProfit,
        expectedMinProfit: expectedMinProfit,
        grossMargin: grossMargin,
        totalProducts: totalProducts,
      );

      _inventoryCache = _DashboardCacheEntry(
        data: inventoryEntity,
        timestamp: DateTime.now(),
      );

      return right(inventoryEntity);
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al obtener métricas de inventario',
        tag: 'DASHBOARD_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return left(
        ServerFailure(message: 'Error al obtener métricas de inventario: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, SalesMetricsEntity>> getSalesMetrics({
    required SalesTimeFilter filter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        '${filter.name}_${customStartDate?.millisecondsSinceEpoch}_${customEndDate?.millisecondsSinceEpoch}';

    if (!forceRefresh &&
        _salesCache.containsKey(cacheKey) &&
        !_salesCache[cacheKey]!.isExpired) {
      return right(_salesCache[cacheKey]!.data);
    }

    try {
      var query = _supabase
          .from('orders')
          .select('id, total_amount, total_profit, created_at')
          .eq('status', 'COMPLETED');

      final now = DateTime.now();

      switch (filter) {
        case SalesTimeFilter.today:
          final startOfDay = DateTime(now.year, now.month, now.day);
          final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          query = query
              .gte('created_at', startOfDay.toUtc().toIso8601String())
              .lte('created_at', endOfDay.toUtc().toIso8601String());
          break;
        case SalesTimeFilter.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeekDay = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          final endOfWeekDay = startOfWeekDay.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999),
          );
          query = query
              .gte('created_at', startOfWeekDay.toUtc().toIso8601String())
              .lte('created_at', endOfWeekDay.toUtc().toIso8601String());
          break;
        case SalesTimeFilter.thisMonth:
          final startOfMonth = DateTime(now.year, now.month, 1);
          final nextMonth = now.month == 12
              ? DateTime(now.year + 1, 1, 1)
              : DateTime(now.year, now.month + 1, 1);
          final endOfMonth = nextMonth.subtract(const Duration(milliseconds: 1));
          query = query
              .gte('created_at', startOfMonth.toUtc().toIso8601String())
              .lte('created_at', endOfMonth.toUtc().toIso8601String());
          break;
        case SalesTimeFilter.custom:
          if (customStartDate != null) {
            final start = DateTime(
              customStartDate.year,
              customStartDate.month,
              customStartDate.day,
            );
            query = query.gte('created_at', start.toUtc().toIso8601String());
          }
          if (customEndDate != null) {
            final end = DateTime(
              customEndDate.year,
              customEndDate.month,
              customEndDate.day,
              23,
              59,
              59,
              999,
            );
            query = query.lte('created_at', end.toUtc().toIso8601String());
          }
          break;
        case SalesTimeFilter.allTime:
          break;
      }

      final response = await query;
      final orders = List<Map<String, dynamic>>.from(response);

      int totalSales = orders.length;
      double totalRevenue = 0.0;
      double totalProfit = 0.0;

      for (var venta in orders) {
        totalRevenue += (venta['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalProfit += (venta['total_profit'] as num?)?.toDouble() ?? 0.0;
      }

      final replacementFund = totalRevenue - totalProfit;
      final averageTicket = totalSales > 0 ? totalRevenue / totalSales : 0.0;
      final salesMargin =
          totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;

      // ── 1. Weekly Activity & Peak Day (In-Memory Processing from Filtered Orders) ──
      final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final Map<int, double> dayTotals = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
      final Map<int, int> dayCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

      for (var o in orders) {
        final createdAtStr = o['created_at'] as String?;
        if (createdAtStr != null) {
          final dt = DateTime.tryParse(createdAtStr)?.toLocal();
          if (dt != null && dt.weekday >= 1 && dt.weekday <= 7) {
            final amt = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
            dayTotals[dt.weekday] = (dayTotals[dt.weekday] ?? 0.0) + amt;
            dayCounts[dt.weekday] = (dayCounts[dt.weekday] ?? 0) + 1;
          }
        }
      }

      int peakWeekday = 1;
      double maxDayVal = 0.0;
      for (var entry in dayTotals.entries) {
        if (entry.value > maxDayVal) {
          maxDayVal = entry.value;
          peakWeekday = entry.key;
        }
      }

      final String peakDayLabel = maxDayVal > 0
          ? '${dayNames[peakWeekday - 1]} pico · S/ ${maxDayVal.toStringAsFixed(0)}'
          : 'Sin ventas en período';

      final List<Map<String, dynamic>> weeklyActivity = [
        {'day': 'Dom', 'val': dayTotals[7] ?? 0.0, 'orders': dayCounts[7] ?? 0, 'active': peakWeekday == 7 && maxDayVal > 0},
        {'day': 'Lun', 'val': dayTotals[1] ?? 0.0, 'orders': dayCounts[1] ?? 0, 'active': peakWeekday == 1 && maxDayVal > 0},
        {'day': 'Mar', 'val': dayTotals[2] ?? 0.0, 'orders': dayCounts[2] ?? 0, 'active': peakWeekday == 2 && maxDayVal > 0},
        {'day': 'Mié', 'val': dayTotals[3] ?? 0.0, 'orders': dayCounts[3] ?? 0, 'active': peakWeekday == 3 && maxDayVal > 0},
        {'day': 'Jue', 'val': dayTotals[4] ?? 0.0, 'orders': dayCounts[4] ?? 0, 'active': peakWeekday == 4 && maxDayVal > 0},
        {'day': 'Vie', 'val': dayTotals[5] ?? 0.0, 'orders': dayCounts[5] ?? 0, 'active': peakWeekday == 5 && maxDayVal > 0},
        {'day': 'Sáb', 'val': dayTotals[6] ?? 0.0, 'orders': dayCounts[6] ?? 0, 'active': peakWeekday == 6 && maxDayVal > 0},
      ];

      // ── 2. Revenue Spline Points ──────────────────────────────────────
      final List<double> revenueTrendPoints;
      if (totalRevenue <= 0) {
        revenueTrendPoints = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      } else {
        revenueTrendPoints = [
          totalRevenue * 0.15,
          totalRevenue * 0.28,
          totalRevenue * 0.42,
          totalRevenue * 0.58,
          totalRevenue * 0.72,
          totalRevenue * 0.88,
          totalRevenue,
        ];
      }

      // ── 3. Best Selling Products (Rotación Real) ──────────────────────
      List<Map<String, dynamic>> bestSellers = [];
      final orderIds = orders.map((o) => o['id'] as String?).whereType<String>().take(40).toList();

      if (orderIds.isNotEmpty) {
        try {
          final itemsResponse = await _supabase
              .from('order_items')
              .select('product_id, quantity, applied_price, products(name)')
              .inFilter('order_id', orderIds);

          final items = List<Map<String, dynamic>>.from(itemsResponse);
          final Map<String, ({String name, int qty, double revenue})> aggregated = {};

          for (var item in items) {
            final prodId = item['product_id'] as String? ?? 'unknown';
            String prodName = 'Producto';
            if (item['products'] is Map && item['products']['name'] != null) {
              prodName = item['products']['name'].toString();
            }
            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['applied_price'] as num?)?.toDouble() ?? 0.0;

            final existing = aggregated[prodId];
            if (existing == null) {
              aggregated[prodId] = (name: prodName, qty: qty, revenue: qty * price);
            } else {
              aggregated[prodId] = (
                name: prodName,
                qty: existing.qty + qty,
                revenue: existing.revenue + (qty * price),
              );
            }
          }

          final sorted = aggregated.entries.toList()
            ..sort((a, b) => b.value.qty.compareTo(a.value.qty));

          bestSellers = sorted.take(5).map((e) {
            return {
              'id': '#${e.key.length > 5 ? e.key.substring(0, 5) : e.key}',
              'productId': e.key,
              'name': e.value.name,
              'category': 'Ventas',
              'sold': '${e.value.qty} unid.',
              'revenue': 'S/ ${e.value.revenue.toStringAsFixed(2)}',
              'rating': '★ 5.0',
              'status': e.value.qty >= 5 ? 'Alta Rotación' : 'Estable',
            };
          }).toList();
        } catch (itemErr) {
          LoggerService.w(
            'No se pudieron cargar items para productos top: $itemErr',
            tag: 'DASHBOARD_REPO',
          );
        }
      }

      final salesEntity = SalesMetricsEntity(
        totalSales: totalSales,
        totalRevenue: totalRevenue,
        totalProfit: totalProfit,
        replacementFund: replacementFund,
        averageTicket: averageTicket,
        salesMargin: salesMargin,
        bestSellers: bestSellers,
        weeklyActivity: weeklyActivity,
        peakDayLabel: peakDayLabel,
        revenueTrendPoints: revenueTrendPoints,
      );

      _salesCache[cacheKey] = _DashboardCacheEntry(
        data: salesEntity,
        timestamp: DateTime.now(),
      );

      return right(salesEntity);
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al obtener métricas de ventas',
        tag: 'DASHBOARD_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return left(
        ServerFailure(message: 'Error al obtener métricas de ventas: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCriticalBatches({
    int daysThreshold = 30,
    int limit = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${daysThreshold}_$limit';

    if (!forceRefresh &&
        _batchesCache.containsKey(cacheKey) &&
        !_batchesCache[cacheKey]!.isExpired) {
      return right(_batchesCache[cacheKey]!.data);
    }

    try {
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final response = await _supabase
          .from('warehouse_stock_batches')
          .select('''
            id, batch_number, expiry_date, available_quantity,
            products(id, name),
            product_variants(
              sku, 
              variant_attribute_values(
                attribute_values(value, attributes(name))
              )
            ),
            warehouses(name)
          ''')
          .not('expiry_date', 'is', null)
          .lte('expiry_date', thresholdDate.toIso8601String().substring(0, 10))
          .gte('expiry_date', now.toIso8601String().substring(0, 10))
          .gt('available_quantity', 0)
          .order('expiry_date')
          .limit(limit);

      final result = List<Map<String, dynamic>>.from(response);
      _batchesCache[cacheKey] = _DashboardCacheEntry(
        data: result,
        timestamp: DateTime.now(),
      );

      return right(result);
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al obtener lotes por vencer',
        tag: 'DASHBOARD_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return left(
        ServerFailure(message: 'Error al obtener lotes por vencer: $e'),
      );
    }
  }
}
