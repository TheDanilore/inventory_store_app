import 'package:supabase_flutter/supabase_flutter.dart';

enum SalesTimeFilter { today, thisWeek, thisMonth, allTime }

class InventoryMetrics {
  final int totalStock;
  final int productosBajoStock;
  final double inversionTotal;
  final double valorVentaMinorista;
  final double gananciaBruta;
  final double gananciaEsperadaMax;
  final double gananciaEsperadaMin;
  final double margenBruto;
  final int totalProductos;

  InventoryMetrics({
    required this.totalStock,
    required this.productosBajoStock,
    required this.inversionTotal,
    required this.valorVentaMinorista,
    required this.gananciaBruta,
    required this.gananciaEsperadaMax,
    required this.gananciaEsperadaMin,
    required this.margenBruto,
    required this.totalProductos,
  });

  factory InventoryMetrics.empty() {
    return InventoryMetrics(
      totalStock: 0,
      productosBajoStock: 0,
      inversionTotal: 0,
      valorVentaMinorista: 0,
      gananciaBruta: 0,
      gananciaEsperadaMax: 0,
      gananciaEsperadaMin: 0,
      margenBruto: 0,
      totalProductos: 0,
    );
  }
}

class SalesMetrics {
  final int totalVentas;
  final double ingresoTotal;
  final double gananciaTotal;
  final double fondoReposicion;
  final double ticketPromedio;
  final double margenVentas;

  SalesMetrics({
    required this.totalVentas,
    required this.ingresoTotal,
    required this.gananciaTotal,
    required this.fondoReposicion,
    required this.ticketPromedio,
    required this.margenVentas,
  });

  factory SalesMetrics.empty() {
    return SalesMetrics(
      totalVentas: 0,
      ingresoTotal: 0,
      gananciaTotal: 0,
      fondoReposicion: 0,
      ticketPromedio: 0,
      margenVentas: 0,
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
            id, name, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, 
            product_variants(id, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active),
            warehouse_stock_batches(variant_id, available_quantity)
          ''')
          .eq('is_active', true)
          .order('name');

      final products = List<Map<String, dynamic>>.from(response);

      int totalStock = 0;
      double inversionTotal = 0.0;
      double valorVentaMinorista = 0.0;
      double gananciaEsperadaMax = 0.0;
      double gananciaEsperadaMin = 0.0;
      double gananciaBruta = 0.0;
      int productosBajoStock = 0;
      int totalProductos = 0;

      for (var row in products) {
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

        totalProductos++;

        final batches = List<Map<String, dynamic>>.from(
          row['warehouse_stock_batches'] ?? [],
        );

        bool prodHasLowStock = false;

        for (final variant in activeVariants) {
          final variantId = variant['id'] as String?;
          if (variantId == null) continue;

          final variantStock = batches
              .where((b) => b['variant_id'] == variantId)
              .fold<int>(
                0,
                (s, b) =>
                    s + ((b['available_quantity'] as num?)?.toInt() ?? 0),
              );

          if (variantStock <= 0) continue;

          final varUnitCost =
              ((variant['unit_cost'] as num?)?.toDouble() ?? 0) > 0
                  ? (variant['unit_cost'] as num).toDouble()
                  : prodUnitCost;

          final varSalePrice = (variant['sale_price'] as num?)?.toDouble() ??
              prodSalePrice;

          final varWholesalePrice =
              (variant['wholesale_price'] as num?)?.toDouble() ??
                  prodWholesalePrice;
          final varWholesaleMinQty =
              (variant['wholesale_min_quantity'] as num?)?.toInt() ??
                  prodWholesaleMinQty;
          final reorderPoint = (variant['reorder_point'] as num?)?.toInt() ?? 3;

          totalStock += variantStock;
          inversionTotal += variantStock * varUnitCost;
          valorVentaMinorista += variantStock * varSalePrice;

          gananciaBruta +=
              (variantStock * varSalePrice) - (variantStock * varUnitCost);
          gananciaEsperadaMax +=
              (variantStock * varSalePrice) - (variantStock * varUnitCost);

          final canApplyWholesale =
              varWholesalePrice != null && variantStock >= varWholesaleMinQty;
          final effectiveWholesale =
              canApplyWholesale ? varWholesalePrice : varSalePrice;
          gananciaEsperadaMin +=
              (variantStock * effectiveWholesale) - (variantStock * varUnitCost);

          if (variantStock <= reorderPoint) prodHasLowStock = true;
        }

        if (prodHasLowStock) productosBajoStock++;
      }

      final margenBruto =
          inversionTotal > 0 ? (gananciaBruta / valorVentaMinorista) * 100 : 0.0;

      return InventoryMetrics(
        totalStock: totalStock,
        productosBajoStock: productosBajoStock,
        inversionTotal: inversionTotal,
        valorVentaMinorista: valorVentaMinorista,
        gananciaBruta: gananciaBruta,
        gananciaEsperadaMax: gananciaEsperadaMax,
        gananciaEsperadaMin: gananciaEsperadaMin,
        margenBruto: margenBruto,
        totalProductos: totalProductos,
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
          final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
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

      int totalVentas = orders.length;
      double ingresoTotal = 0.0;
      double gananciaTotal = 0.0;

      for (var venta in orders) {
        ingresoTotal += (venta['total_amount'] as num?)?.toDouble() ?? 0.0;
        gananciaTotal += (venta['total_profit'] as num?)?.toDouble() ?? 0.0;
      }

      final fondoReposicion = ingresoTotal - gananciaTotal;
      final ticketPromedio = totalVentas > 0 ? ingresoTotal / totalVentas : 0.0;
      final margenVentas =
          ingresoTotal > 0 ? (gananciaTotal / ingresoTotal) * 100 : 0.0;

      return SalesMetrics(
        totalVentas: totalVentas,
        ingresoTotal: ingresoTotal,
        gananciaTotal: gananciaTotal,
        fondoReposicion: fondoReposicion,
        ticketPromedio: ticketPromedio,
        margenVentas: margenVentas,
      );
    } catch (e) {
      throw Exception('Error al obtener métricas de ventas: \$e');
    }
  }
}
