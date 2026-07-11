import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/inventory_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_metrics_entity.dart';
import 'package:inventory_store_app/features/dashboard/domain/entities/sales_time_filter.dart';
import 'package:inventory_store_app/features/dashboard/domain/repositories/dashboard_repository.dart';

@LazySingleton(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  final SupabaseClient _supabase;

  DashboardRepositoryImpl(this._supabase);

  @override
  Future<Either<Failure, InventoryMetricsEntity>> getInventoryMetrics() async {
    try {
      final response = await _supabase
          .from('products')
          .select('''
            id, name, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, stock_control,
            product_variants(id, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active),
            warehouse_stock_batches(variant_id, available_quantity)
          ''')
          .eq('is_active', true)
          .order('name');

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

      return right(InventoryMetricsEntity(
        totalStock: totalStock,
        lowStockProducts: lowStockProducts,
        totalInvestment: totalInvestment,
        retailValue: retailValue,
        grossProfit: grossProfit,
        expectedMaxProfit: expectedMaxProfit,
        expectedMinProfit: expectedMinProfit,
        grossMargin: grossMargin,
        totalProducts: totalProducts,
      ));
    } catch (e) {
      return left(ServerFailure(message: 'Error al obtener métricas de inventario: $e'));
    }
  }

  @override
  Future<Either<Failure, SalesMetricsEntity>> getSalesMetrics({
    required SalesTimeFilter filter,
  }) async {
    try {
      var query = _supabase
          .from('orders')
          .select('total_amount, total_profit')
          .eq('status', 'COMPLETED');

      final now = DateTime.now();

      switch (filter) {
        case SalesTimeFilter.today:
          final startOfDay = DateTime(now.year, now.month, now.day);
          query = query.gte('created_at', startOfDay.toIso8601String());
          break;
        case SalesTimeFilter.thisWeek:
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfWeekDay = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          query = query.gte('created_at', startOfWeekDay.toIso8601String());
          break;
        case SalesTimeFilter.thisMonth:
          final startOfMonth = DateTime(now.year, now.month, 1);
          query = query.gte('created_at', startOfMonth.toIso8601String());
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

      return right(SalesMetricsEntity(
        totalSales: totalSales,
        totalRevenue: totalRevenue,
        totalProfit: totalProfit,
        replacementFund: replacementFund,
        averageTicket: averageTicket,
        salesMargin: salesMargin,
      ));
    } catch (e) {
      return left(ServerFailure(message: 'Error al obtener métricas de ventas: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCriticalBatches({
    int daysThreshold = 30,
  }) async {
    try {
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));

      final response = await _supabase
          .from('warehouse_stock_batches')
          .select('''
            id, batch_number, expiry_date, available_quantity,
            products(name),
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
          .order('expiry_date');

      return right(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      return left(ServerFailure(message: 'Error al obtener lotes por vencer: $e'));
    }
  }
}


