import 'package:supabase_flutter/supabase_flutter.dart';

enum SalesTimeFilter { today, thisWeek, thisMonth, allTime }

class InventoryMetrics {
  final int totalStock;
  final int lowStockProducts;
  final double totalInvestment;
  final double retailValue;
  final double grossProfit;
  final double expectedMaxProfit;
  final double expectedMinProfit;
  final double grossMargin;
  final int totalProducts;

  InventoryMetrics({
    required this.totalStock,
    required this.lowStockProducts,
    required this.totalInvestment,
    required this.retailValue,
    required this.grossProfit,
    required this.expectedMaxProfit,
    required this.expectedMinProfit,
    required this.grossMargin,
    required this.totalProducts,
  });

  factory InventoryMetrics.empty() {
    return InventoryMetrics(
      totalStock: 0,
      lowStockProducts: 0,
      totalInvestment: 0,
      retailValue: 0,
      grossProfit: 0,
      expectedMaxProfit: 0,
      expectedMinProfit: 0,
      grossMargin: 0,
      totalProducts: 0,
    );
  }
}

class SalesMetrics {
  final int totalSales;
  final double totalRevenue;
  final double totalProfit;
  final double replacementFund;
  final double averageTicket;
  final double salesMargin;

  SalesMetrics({
    required this.totalSales,
    required this.totalRevenue,
    required this.totalProfit,
    required this.replacementFund,
    required this.averageTicket,
    required this.salesMargin,
  });

  factory SalesMetrics.empty() {
    return SalesMetrics(
      totalSales: 0,
      totalRevenue: 0,
      totalProfit: 0,
      replacementFund: 0,
      averageTicket: 0,
      salesMargin: 0,
    );
  }
}

class DashboardService {
  final SupabaseClient _supabase;

  DashboardService() : _supabase = Supabase.instance.client;

  Future<InventoryMetrics> getInventoryMetrics() async {
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
          } else {
            // Si no tiene stock control, usualmente variantStock es 0 o no lo sumamos al total general
            // pero si por algun motivo hay stock, para igualar a inventory_service, sumamos.
            // En inventory_service totalStock += variantStock solo si stockControl == true.
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

      return InventoryMetrics(
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
    } catch (e) {
      throw Exception('Error al obtener métricas de inventario: \$e');
    }
  }

  Future<List<Map<String, dynamic>>> getExpiringBatches() async {
    try {
      final now = DateTime.now();
      final in30Days = now.add(const Duration(days: 30));

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
          .lte('expiry_date', in30Days.toIso8601String().substring(0, 10))
          .gte('expiry_date', now.toIso8601String().substring(0, 10))
          .gt('available_quantity', 0)
          .order('expiry_date');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener lotes por vencer: \$e');
    }
  }

  Future<SalesMetrics> getSalesMetrics(SalesTimeFilter filter) async {
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

      return SalesMetrics(
        totalSales: totalSales,
        totalRevenue: totalRevenue,
        totalProfit: totalProfit,
        replacementFund: replacementFund,
        averageTicket: averageTicket,
        salesMargin: salesMargin,
      );
    } catch (e) {
      throw Exception('Error al obtener métricas de ventas: \$e');
    }
  }
}
