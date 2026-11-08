import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/customer_credit_aging_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_overview.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/stagnant_product_entity.dart';
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
      DateTime.now().difference(timestamp) > const Duration(minutes: 10);
}

@LazySingleton(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  final SupabaseClient _supabase;

  final Map<String, _DashboardCacheEntry<InventoryMetricsEntity>>
  _inventoryCache = {};
  final Map<String, _DashboardCacheEntry<SalesMetricsEntity>> _salesCache = {};
  final Map<String, _DashboardCacheEntry<List<Map<String, dynamic>>>>
  _batchesCache = {};
  final Map<String, _DashboardCacheEntry<List<StagnantProductEntity>>>
  _stagnantCache = {};
  final Map<String, _DashboardCacheEntry<List<CustomerCreditAgingEntity>>>
  _creditsAgingCache = {};

  DashboardRepositoryImpl(this._supabase);

  /// Ventas por rango con serie temporal real y actividad por día de la semana
  /// (RPC `get_dashboard_sales_overview`). from/to null = todo el histórico.
  @override
  Future<Either<Failure, SalesOverview>> getSalesOverview({
    required DateTime? from,
    required DateTime? to,
    String? warehouseId,
  }) async {
    try {
      String? fmt(DateTime? d) =>
          d == null
              ? null
              : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final res = await _supabase.rpc(
        'get_dashboard_sales_overview',
        params: {
          'p_from': fmt(from),
          'p_to': fmt(to),
          'p_warehouse_id': warehouseId,
        },
      );
      return right(
        SalesOverview.fromJson(Map<String, dynamic>.from(res as Map)),
      );
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al obtener resumen de ventas',
        tag: 'DASHBOARD_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      return left(
        ServerFailure(message: 'Error al obtener resumen de ventas: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, InventoryMetricsEntity>> getInventoryMetrics({
    bool forceRefresh = false,
    String? warehouseId,
  }) async {
    final cacheKey = warehouseId ?? 'all';
    if (!forceRefresh &&
        _inventoryCache.containsKey(cacheKey) &&
        !_inventoryCache[cacheKey]!.isExpired) {
      return right(_inventoryCache[cacheKey]!.data);
    }

    // 1. Intentar RPC optimizada en Supabase para Data Egress casi nulo (cálculo en PostgreSQL)
    try {
      final rpcParams =
          warehouseId != null ? {'p_warehouse_id': warehouseId} : null;
      final rpcResponse = await _supabase.rpc(
        'get_dashboard_inventory_metrics',
        params: rpcParams,
      );
      if (rpcResponse != null && rpcResponse is Map) {
        final totalStock = (rpcResponse['total_stock'] as num?)?.toInt() ?? 0;
        final totalProducts =
            (rpcResponse['total_products'] as num?)?.toInt() ?? 0;
        final lowStockProducts =
            (rpcResponse['low_stock_products'] as num?)?.toInt() ?? 0;
        final totalInvestment =
            (rpcResponse['total_investment'] as num?)?.toDouble() ?? 0.0;
        final retailValue =
            (rpcResponse['retail_value'] as num?)?.toDouble() ?? 0.0;
        final grossProfit =
            (rpcResponse['gross_profit'] as num?)?.toDouble() ?? 0.0;
        final grossMargin =
            totalInvestment > 0 && retailValue > 0
                ? (grossProfit / retailValue) * 100
                : 0.0;

        final inventoryEntity = InventoryMetricsEntity(
          totalStock: totalStock,
          lowStockProducts: lowStockProducts,
          totalInvestment: totalInvestment,
          retailValue: retailValue,
          grossProfit: grossProfit,
          expectedMaxProfit: grossProfit,
          expectedMinProfit: grossProfit * 0.9,
          grossMargin: grossMargin,
          totalProducts: totalProducts,
        );

        _inventoryCache[cacheKey] = _DashboardCacheEntry(
          data: inventoryEntity,
          timestamp: DateTime.now(),
        );

        return right(inventoryEntity);
      }
    } catch (rpcErr) {
      LoggerService.w(
        'RPC get_dashboard_inventory_metrics no disponible, usando fallback cliente: $rpcErr',
        tag: 'DASHBOARD_REPO',
      );
    }

    try {
      final response = await _supabase
          .from('products')
          .select('''
            id, name, is_active, stock_control,
            product_variants(id, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active),
            warehouse_stock_batches(variant_id, warehouse_id, available_quantity)
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
        final filteredBatches =
            warehouseId == null
                ? batches
                : batches
                    .where((b) => b['warehouse_id'] == warehouseId)
                    .toList();

        for (final variant in activeVariants) {
          final variantId = variant['id'] as String?;
          if (variantId == null) continue;

          final variantStock = filteredBatches
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

      _inventoryCache[cacheKey] = _DashboardCacheEntry(
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
      if (_inventoryCache.containsKey(cacheKey)) {
        LoggerService.w(
          'Retornando métricas de inventario desde caché previo tras fallo de red',
          tag: 'DASHBOARD_REPO',
        );
        return right(_inventoryCache[cacheKey]!.data);
      }
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
    String? warehouseId,
  }) async {
    final cacheKey =
        '${filter.name}_${customStartDate?.millisecondsSinceEpoch}_${customEndDate?.millisecondsSinceEpoch}_$warehouseId';

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

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final now = DateTime.now();

      switch (filter) {
        case SalesTimeFilter.today:
          final startOfDay = DateTime(now.year, now.month, now.day);
          final endOfDay = DateTime(
            now.year,
            now.month,
            now.day,
            23,
            59,
            59,
            999,
          );
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
            const Duration(
              days: 6,
              hours: 23,
              minutes: 59,
              seconds: 59,
              milliseconds: 999,
            ),
          );
          query = query
              .gte('created_at', startOfWeekDay.toUtc().toIso8601String())
              .lte('created_at', endOfWeekDay.toUtc().toIso8601String());
          break;
        case SalesTimeFilter.thisMonth:
          final startOfMonth = DateTime(now.year, now.month, 1);
          final nextMonth =
              now.month == 12
                  ? DateTime(now.year + 1, 1, 1)
                  : DateTime(now.year, now.month + 1, 1);
          final endOfMonth = nextMonth.subtract(
            const Duration(milliseconds: 1),
          );
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
      final Map<int, double> dayTotals = {
        1: 0.0,
        2: 0.0,
        3: 0.0,
        4: 0.0,
        5: 0.0,
        6: 0.0,
        7: 0.0,
      };
      final Map<int, int> dayCounts = {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
        6: 0,
        7: 0,
      };

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

      final String peakDayLabel =
          maxDayVal > 0
              ? '${dayNames[peakWeekday - 1]} pico · S/ ${maxDayVal.toStringAsFixed(0)}'
              : 'Sin ventas en período';

      final List<Map<String, dynamic>> weeklyActivity = [
        {
          'day': 'Dom',
          'val': dayTotals[7] ?? 0.0,
          'orders': dayCounts[7] ?? 0,
          'active': peakWeekday == 7 && maxDayVal > 0,
        },
        {
          'day': 'Lun',
          'val': dayTotals[1] ?? 0.0,
          'orders': dayCounts[1] ?? 0,
          'active': peakWeekday == 1 && maxDayVal > 0,
        },
        {
          'day': 'Mar',
          'val': dayTotals[2] ?? 0.0,
          'orders': dayCounts[2] ?? 0,
          'active': peakWeekday == 2 && maxDayVal > 0,
        },
        {
          'day': 'Mié',
          'val': dayTotals[3] ?? 0.0,
          'orders': dayCounts[3] ?? 0,
          'active': peakWeekday == 3 && maxDayVal > 0,
        },
        {
          'day': 'Jue',
          'val': dayTotals[4] ?? 0.0,
          'orders': dayCounts[4] ?? 0,
          'active': peakWeekday == 4 && maxDayVal > 0,
        },
        {
          'day': 'Vie',
          'val': dayTotals[5] ?? 0.0,
          'orders': dayCounts[5] ?? 0,
          'active': peakWeekday == 5 && maxDayVal > 0,
        },
        {
          'day': 'Sáb',
          'val': dayTotals[6] ?? 0.0,
          'orders': dayCounts[6] ?? 0,
          'active': peakWeekday == 6 && maxDayVal > 0,
        },
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
      final orderIds =
          orders
              .map((o) => o['id'] as String?)
              .whereType<String>()
              .take(40)
              .toList();

      if (orderIds.isNotEmpty) {
        try {
          final itemsResponse = await _supabase
              .from('order_items')
              .select('''
                product_id, variant_id, quantity, applied_price,
                products(
                  id, name,
                  categories(name),
                  product_images(image_url, is_main)
                ),
                product_variants(
                  id,
                  product_images(image_url, is_main)
                )
              ''')
              .inFilter('order_id', orderIds);

          final items = List<Map<String, dynamic>>.from(itemsResponse);
          final Map<
            String,
            ({
              String name,
              String? imageUrl,
              String category,
              int qty,
              double revenue,
            })
          >
          aggregated = {};

          for (var item in items) {
            final prodId = item['product_id'] as String? ?? 'unknown';
            String prodName = 'Producto';
            String category = 'General';
            String? imageUrl;

            if (item['products'] is Map) {
              final prodMap = item['products'] as Map<String, dynamic>;
              if (prodMap['name'] != null) {
                prodName = prodMap['name'].toString();
              }
              if (prodMap['categories'] is Map &&
                  prodMap['categories']['name'] != null) {
                category = prodMap['categories']['name'].toString();
              }
              final prodImgs =
                  prodMap['product_images'] as List<dynamic>? ?? [];
              if (prodImgs.isNotEmpty) {
                final mainImg =
                    prodImgs.firstWhere(
                          (img) =>
                              (img as Map<String, dynamic>)['is_main'] == true,
                          orElse: () => prodImgs.first,
                        )
                        as Map<String, dynamic>?;
                imageUrl = mainImg?['image_url'] as String?;
              }
            }

            if (imageUrl == null && item['product_variants'] is Map) {
              final varMap = item['product_variants'] as Map<String, dynamic>;
              final varImgs = varMap['product_images'] as List<dynamic>? ?? [];
              if (varImgs.isNotEmpty) {
                final mainImg =
                    varImgs.firstWhere(
                          (img) =>
                              (img as Map<String, dynamic>)['is_main'] == true,
                          orElse: () => varImgs.first,
                        )
                        as Map<String, dynamic>?;
                imageUrl = mainImg?['image_url'] as String?;
              }
            }

            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['applied_price'] as num?)?.toDouble() ?? 0.0;

            final existing = aggregated[prodId];
            if (existing == null) {
              aggregated[prodId] = (
                name: prodName,
                imageUrl: imageUrl,
                category: category,
                qty: qty,
                revenue: qty * price,
              );
            } else {
              aggregated[prodId] = (
                name: prodName,
                imageUrl: existing.imageUrl ?? imageUrl,
                category:
                    existing.category != 'General'
                        ? existing.category
                        : category,
                qty: existing.qty + qty,
                revenue: existing.revenue + (qty * price),
              );
            }
          }

          final sorted =
              aggregated.entries.toList()
                ..sort((a, b) => b.value.qty.compareTo(a.value.qty));

          bestSellers =
              sorted.take(5).map((e) {
                return {
                  'id': '#${e.key.length > 5 ? e.key.substring(0, 5) : e.key}',
                  'productId': e.key,
                  'name': e.value.name,
                  'imageUrl': e.value.imageUrl,
                  'category': e.value.category,
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
      if (_salesCache.containsKey(cacheKey)) {
        LoggerService.w(
          'Retornando métricas de ventas desde caché previo tras fallo de red',
          tag: 'DASHBOARD_REPO',
        );
        return right(_salesCache[cacheKey]!.data);
      }
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
    String? warehouseId,
  }) async {
    final cacheKey = '${daysThreshold}_${limit}_$warehouseId';

    if (!forceRefresh &&
        _batchesCache.containsKey(cacheKey) &&
        !_batchesCache[cacheKey]!.isExpired) {
      return right(_batchesCache[cacheKey]!.data);
    }

    try {
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      var query = _supabase
          .from('warehouse_stock_batches')
          .select('''
            id, batch_number, expiry_date, available_quantity, warehouse_id,
            products(
              id, name,
              product_images(image_url, is_main)
            ),
            product_variants(
              sku, 
              product_images(image_url, is_main),
              variant_attribute_values(
                attribute_values(value, attributes(name))
              )
            ),
            warehouses(name)
          ''')
          .not('expiry_date', 'is', null)
          .lte('expiry_date', thresholdDate.toIso8601String().substring(0, 10))
          .gt('available_quantity', 0);

      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }

      final response = await query
          .order('expiry_date', ascending: true)
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
      if (_batchesCache.containsKey(cacheKey)) {
        LoggerService.w(
          'Retornando lotes críticos desde caché previo tras fallo de red',
          tag: 'DASHBOARD_REPO',
        );
        return right(_batchesCache[cacheKey]!.data);
      }
      return left(
        ServerFailure(message: 'Error al obtener lotes por vencer: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<StagnantProductEntity>>> getStagnantProducts({
    String? warehouseId,
    int limit = 5,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${warehouseId ?? "all"}_$limit';

    if (!forceRefresh &&
        _stagnantCache.containsKey(cacheKey) &&
        !_stagnantCache[cacheKey]!.isExpired) {
      return right(_stagnantCache[cacheKey]!.data);
    }

    try {
      // 1. Obtener productos activos con variantes y lotes de stock
      final response = await _supabase
          .from('products')
          .select('''
            id, name, is_active, created_at,
            categories(name),
            product_images(image_url, is_main),
            product_variants(id, unit_cost, sale_price, is_active),
            warehouse_stock_batches(variant_id, warehouse_id, available_quantity)
          ''')
          .eq('is_active', true);

      final products = List<Map<String, dynamic>>.from(response);
      final List<({
        String id,
        String name,
        String category,
        String? imageUrl,
        int stock,
        double unitCost,
        double salePrice,
        double tiedUpCapital,
        DateTime createdAt,
      })> inStockProducts = [];

      for (final p in products) {
        final prodId = p['id']?.toString() ?? '';
        if (prodId.isEmpty) continue;

        final prodName = p['name']?.toString() ?? 'Producto';
        String category = 'General';
        if (p['categories'] is Map && p['categories']['name'] != null) {
          category = p['categories']['name'].toString();
        }

        String? imageUrl;
        final prodImgs = p['product_images'] as List<dynamic>? ?? [];
        if (prodImgs.isNotEmpty) {
          final mainImg = prodImgs.firstWhere(
            (img) => (img as Map<String, dynamic>)['is_main'] == true,
            orElse: () => prodImgs.first,
          ) as Map<String, dynamic>?;
          imageUrl = mainImg?['image_url'] as String?;
        }

        final batches = List<Map<String, dynamic>>.from(
          p['warehouse_stock_batches'] ?? [],
        );
        final filteredBatches = warehouseId == null
            ? batches
            : batches.where((b) => b['warehouse_id'] == warehouseId).toList();

        final totalStock = filteredBatches.fold<int>(
          0,
          (sum, b) => sum + ((b['available_quantity'] as num?)?.toInt() ?? 0),
        );

        if (totalStock <= 0) continue;

        final variants = List<Map<String, dynamic>>.from(
          p['product_variants'] ?? [],
        );
        double avgCost = 0.0;
        double avgPrice = 0.0;
        if (variants.isNotEmpty) {
          final activeVariants =
              variants.where((v) => v['is_active'] == true).toList();
          final targetList = activeVariants.isNotEmpty ? activeVariants : variants;
          double costSum = 0.0;
          double priceSum = 0.0;
          for (final v in targetList) {
            costSum += (v['unit_cost'] as num?)?.toDouble() ?? 0.0;
            priceSum += (v['sale_price'] as num?)?.toDouble() ?? 0.0;
          }
          avgCost = costSum / targetList.length;
          avgPrice = priceSum / targetList.length;
        }

        final valuationRate = avgCost > 0 ? avgCost : avgPrice;
        final tiedUpCapital = totalStock * valuationRate;
        final createdAt = p['created_at'] != null
            ? (DateTime.tryParse(p['created_at'].toString()) ?? DateTime.now())
            : DateTime.now();

        inStockProducts.add((
          id: prodId,
          name: prodName,
          category: category,
          imageUrl: imageUrl,
          stock: totalStock,
          unitCost: avgCost,
          salePrice: avgPrice,
          tiedUpCapital: tiedUpCapital,
          createdAt: createdAt,
        ));
      }

      if (inStockProducts.isEmpty) {
        _stagnantCache[cacheKey] = _DashboardCacheEntry(
          data: [],
          timestamp: DateTime.now(),
        );
        return right([]);
      }

      // 2. Consultar fecha de última salida/venta para los productos en stock
      final productIds = inStockProducts.map((p) => p.id).toList();
      final Map<String, DateTime> lastSaleDates = {};

      try {
        final orderItemsResp = await _supabase
            .from('order_items')
            .select('product_id, created_at')
            .inFilter('product_id', productIds)
            .order('created_at', ascending: false);

        for (final item in (orderItemsResp as List)) {
          final pid = item['product_id']?.toString();
          final dtStr = item['created_at']?.toString();
          if (pid != null && dtStr != null && !lastSaleDates.containsKey(pid)) {
            final dt = DateTime.tryParse(dtStr);
            if (dt != null) {
              lastSaleDates[pid] = dt;
            }
          }
        }
      } catch (err) {
        LoggerService.w(
          'Error consultando order_items para productos sin rotación: $err',
          tag: 'DASHBOARD_REPO',
        );
      }

      final now = DateTime.now();
      final List<StagnantProductEntity> stagnantEntities = [];

      for (final p in inStockProducts) {
        final lastSale = lastSaleDates[p.id];
        final daysWithoutSale = lastSale != null
            ? now.difference(lastSale).inDays
            : now.difference(p.createdAt).inDays;

        stagnantEntities.add(StagnantProductEntity(
          id: p.id,
          name: p.name,
          category: p.category,
          imageUrl: p.imageUrl,
          currentStock: p.stock,
          unitCost: p.unitCost,
          salePrice: p.salePrice,
          tiedUpCapital: p.tiedUpCapital,
          daysWithoutSale: daysWithoutSale < 0 ? 0 : daysWithoutSale,
          lastSaleDate: lastSale,
        ));
      }

      // 3. Ordenar priorizando capital inmovilizado y mayor tiempo sin salir
      stagnantEntities.sort((a, b) {
        // Primero productos que nunca se vendieron o tienen más de 15 días sin rotar
        final aCritical = a.daysWithoutSale >= 15 || a.lastSaleDate == null;
        final bCritical = b.daysWithoutSale >= 15 || b.lastSaleDate == null;
        if (aCritical && !bCritical) return -1;
        if (!aCritical && bCritical) return 1;

        // Luego por mayor capital inmovilizado (dinero estancado)
        final cmpCapital = b.tiedUpCapital.compareTo(a.tiedUpCapital);
        if (cmpCapital != 0) return cmpCapital;

        return b.daysWithoutSale.compareTo(a.daysWithoutSale);
      });

      final result = stagnantEntities.take(limit).toList();
      _stagnantCache[cacheKey] = _DashboardCacheEntry(
        data: result,
        timestamp: DateTime.now(),
      );

      return right(result);
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al obtener productos sin rotación',
        tag: 'DASHBOARD_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      if (_stagnantCache.containsKey(cacheKey)) {
        return right(_stagnantCache[cacheKey]!.data);
      }
      return left(
        ServerFailure(message: 'Error al obtener productos sin rotación: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<CustomerCreditAgingEntity>>> getActiveCreditsAging({
    int limit = 5,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$limit';

    if (!forceRefresh &&
        _creditsAgingCache.containsKey(cacheKey) &&
        !_creditsAgingCache[cacheKey]!.isExpired) {
      return right(_creditsAgingCache[cacheKey]!.data);
    }

    try {
      // 1. Obtener créditos de clientes activos que tienen deuda vigente (> 0)
      dynamic response;
      try {
        response = await _supabase
            .from('customer_credits')
            .select('''
              id, profile_id, credit_limit, current_debt, is_active, created_at, updated_at,
              profiles!customer_credits_profile_id_fkey!inner ( id, full_name, phone, document_number, document_type )
            ''')
            .eq('is_active', true)
            .gt('current_debt', 0)
            .order('current_debt', ascending: false)
            .limit(limit * 2);
      } catch (innerErr) {
        LoggerService.w(
          'Consulta con inner join fkey falló, usando fallback de perfiles: $innerErr',
          tag: 'DASHBOARD_REPO',
        );
        response = await _supabase
            .from('customer_credits')
            .select('''
              id, profile_id, credit_limit, current_debt, is_active, created_at, updated_at,
              profiles ( id, full_name, phone, document_number, document_type )
            ''')
            .eq('is_active', true)
            .gt('current_debt', 0)
            .order('current_debt', ascending: false)
            .limit(limit * 2);
      }

      final creditRows = List<Map<String, dynamic>>.from(response as List);
      if (creditRows.isEmpty) {
        _creditsAgingCache[cacheKey] = _DashboardCacheEntry(
          data: [],
          timestamp: DateTime.now(),
        );
        return right([]);
      }

      final creditIds = creditRows.map((r) => r['id'].toString()).toList();

      // 2. Obtener movimientos de crédito (cargos y abonos) para analizar tiempos
      final movementsResponse = await _supabase
          .from('customer_credit_movements')
          .select('id, customer_credit_id, movement_type, amount, created_at')
          .inFilter('customer_credit_id', creditIds)
          .order('created_at', ascending: true);

      final movements = List<Map<String, dynamic>>.from(movementsResponse as List);
      final Map<String, List<Map<String, dynamic>>> movementsByCreditId = {};
      for (final m in movements) {
        final cid = m['customer_credit_id']?.toString() ?? '';
        if (cid.isNotEmpty) {
          movementsByCreditId.putIfAbsent(cid, () => []).add(m);
        }
      }

      final now = DateTime.now();
      final List<CustomerCreditAgingEntity> resultList = [];

      for (final row in creditRows) {
        final creditId = row['id']?.toString() ?? '';
        final profileId = row['profile_id']?.toString() ?? '';
        final creditLimit = (row['credit_limit'] as num?)?.toDouble() ?? 0.0;
        final currentDebt = (row['current_debt'] as num?)?.toDouble() ?? 0.0;
        final isActive = row['is_active'] as bool? ?? true;
        final creditCreatedAt = row['created_at'] != null
            ? DateTime.tryParse(row['created_at'].toString())
            : null;

        final profile = row['profiles'] as Map<String, dynamic>? ?? {};
        final customerName = profile['full_name']?.toString() ?? 'Cliente';
        final customerPhone = profile['phone']?.toString();
        final customerDocument = profile['document_number']?.toString();

        final accountMovements = movementsByCreditId[creditId] ?? [];
        final charges = accountMovements
            .where((m) => m['movement_type'] == 'CHARGE')
            .toList();
        final payments = accountMovements
            .where((m) => m['movement_type'] == 'PAYMENT')
            .toList();

        // Última fecha de cargo (cuando se le dio el crédito)
        DateTime? lastChargeDate;
        if (charges.isNotEmpty) {
          final lastC = charges.last['created_at']?.toString();
          if (lastC != null) lastChargeDate = DateTime.tryParse(lastC);
        }
        lastChargeDate ??= creditCreatedAt;

        // Última fecha de abono
        DateTime? lastPaymentDate;
        if (payments.isNotEmpty) {
          final lastP = payments.last['created_at']?.toString();
          if (lastP != null) lastPaymentDate = DateTime.tryParse(lastP);
        }

        // Antigüedad de la deuda vigente en días
        final daysWithDebt = lastChargeDate != null
            ? now.difference(lastChargeDate).inDays.clamp(0, 9999)
            : 0;

        // Cálculo de cuánto se demoran en pagar (Promedio histórico de demora)
        final paymentDelays = <int>[];
        for (final payment in payments) {
          final paymentTimeStr = payment['created_at']?.toString();
          if (paymentTimeStr == null) continue;
          final paymentTime = DateTime.tryParse(paymentTimeStr);
          if (paymentTime == null) continue;

          // Buscar el cargo anterior más cercano
          DateTime? previousChargeTime;
          for (final charge in charges.reversed) {
            final chargeTimeStr = charge['created_at']?.toString();
            if (chargeTimeStr == null) continue;
            final chargeTime = DateTime.tryParse(chargeTimeStr);
            if (chargeTime != null && chargeTime.isBefore(paymentTime)) {
              previousChargeTime = chargeTime;
              break;
            }
          }

          if (previousChargeTime != null) {
            final diff = paymentTime.difference(previousChargeTime).inDays;
            if (diff >= 0) paymentDelays.add(diff);
          }
        }

        final averagePaymentDays = paymentDelays.isNotEmpty
            ? paymentDelays.reduce((a, b) => a + b) / paymentDelays.length
            : (payments.isNotEmpty ? 1.0 : 0.0);

        resultList.add(CustomerCreditAgingEntity(
          creditId: creditId,
          customerId: profileId,
          customerName: customerName,
          customerPhone: customerPhone,
          customerDocument: customerDocument,
          creditLimit: creditLimit,
          currentDebt: currentDebt,
          isActive: isActive,
          daysWithDebt: daysWithDebt,
          averagePaymentDays: averagePaymentDays,
          totalPaymentsCount: payments.length,
          lastChargeDate: lastChargeDate,
          lastPaymentDate: lastPaymentDate,
        ));
      }

      // Ordenar por mayor deuda y luego por mayor antigüedad de mora
      resultList.sort((a, b) {
        final cmpDebt = b.currentDebt.compareTo(a.currentDebt);
        if (cmpDebt != 0) return cmpDebt;
        return b.daysWithDebt.compareTo(a.daysWithDebt);
      });

      final finalResult = resultList.take(limit).toList();
      _creditsAgingCache[cacheKey] = _DashboardCacheEntry(
        data: finalResult,
        timestamp: DateTime.now(),
      );

      return right(finalResult);
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al obtener créditos vigentes con antigüedad',
        tag: 'DASHBOARD_REPO',
        error: e,
        stackTrace: stackTrace,
      );
      if (_creditsAgingCache.containsKey(cacheKey)) {
        return right(_creditsAgingCache[cacheKey]!.data);
      }
      return left(
        ServerFailure(message: 'Error al obtener créditos vigentes: $e'),
      );
    }
  }
}
