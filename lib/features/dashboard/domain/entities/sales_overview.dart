import 'package:equatable/equatable.dart';

enum SalesBucket { day, week, month }

/// Un punto de la serie temporal (un día, una semana o un mes según el rango).
class SalesTrendPoint extends Equatable {
  final DateTime date; // inicio del bucket (nunca anterior al inicio del rango)
  final double revenue;
  final double profit;
  final int orders;

  const SalesTrendPoint({
    required this.date,
    required this.revenue,
    required this.profit,
    required this.orders,
  });

  factory SalesTrendPoint.fromJson(Map<String, dynamic> j) => SalesTrendPoint(
    date: DateTime.parse(j['date'] as String),
    revenue: (j['revenue'] as num).toDouble(),
    profit: (j['profit'] as num).toDouble(),
    orders: (j['orders'] as num).toInt(),
  );

  @override
  List<Object?> get props => [date, revenue, profit, orders];
}

/// Ventas acumuladas de un día de la semana dentro del rango (1 = lunes … 7 = domingo).
class WeekdayActivity extends Equatable {
  final int isoDow;
  final double revenue;
  final int orders;

  const WeekdayActivity({
    required this.isoDow,
    required this.revenue,
    required this.orders,
  });

  factory WeekdayActivity.fromJson(Map<String, dynamic> j) => WeekdayActivity(
    isoDow: (j['iso_dow'] as num).toInt(),
    revenue: (j['revenue'] as num).toDouble(),
    orders: (j['orders'] as num).toInt(),
  );

  @override
  List<Object?> get props => [isoDow, revenue, orders];
}

/// Respuesta de la RPC `get_dashboard_sales_overview`.
class SalesOverview extends Equatable {
  final DateTime from;
  final DateTime to;
  final int days;
  final SalesBucket bucket;
  final double totalRevenue;
  final double totalProfit;

  /// Cobrado de los pedidos del rango (orders.amount_paid). Las ventas a crédito
  /// cuentan completas en ingresos; aquí solo lo ya pagado.
  final double totalCollected;
  final int totalOrders;
  final double prevRevenue;
  final double prevProfit;
  final int prevOrders;
  final List<SalesTrendPoint> trend;
  final List<WeekdayActivity> weekday;

  const SalesOverview({
    required this.from,
    required this.to,
    required this.days,
    required this.bucket,
    required this.totalRevenue,
    required this.totalProfit,
    this.totalCollected = 0,
    required this.totalOrders,
    required this.prevRevenue,
    required this.prevProfit,
    required this.prevOrders,
    required this.trend,
    required this.weekday,
  });

  factory SalesOverview.fromJson(Map<String, dynamic> j) {
    double d(String k) => ((j[k] ?? 0) as num).toDouble();
    int i(String k) => ((j[k] ?? 0) as num).toInt();
    return SalesOverview(
      from: DateTime.parse(j['from'] as String),
      to: DateTime.parse(j['to'] as String),
      days: i('days'),
      bucket: SalesBucket.values.firstWhere(
        (b) => b.name == j['bucket'],
        orElse: () => SalesBucket.day,
      ),
      totalRevenue: d('total_revenue'),
      totalProfit: d('total_profit'),
      totalCollected: d('total_collected'),
      totalOrders: i('total_orders'),
      prevRevenue: d('prev_revenue'),
      prevProfit: d('prev_profit'),
      prevOrders: i('prev_orders'),
      trend:
          (j['trend'] as List? ?? [])
              .map(
                (e) => SalesTrendPoint.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(),
      weekday:
          (j['weekday'] as List? ?? [])
              .map(
                (e) => WeekdayActivity.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(),
    );
  }

  /// Por cobrar = ingresos - cobrado (nunca negativo).
  double get pendingCollection =>
      totalRevenue > totalCollected ? totalRevenue - totalCollected : 0;

  double get costOfGoods => totalRevenue - totalProfit;
  double get margin => totalRevenue > 0 ? totalProfit / totalRevenue * 100 : 0;
  double get averageTicket => totalOrders > 0 ? totalRevenue / totalOrders : 0;

  /// Variación % de ingresos contra el periodo anterior; null si no había base.
  double? get revenueDelta =>
      prevRevenue > 0 ? (totalRevenue - prevRevenue) / prevRevenue * 100 : null;

  @override
  List<Object?> get props => [
    from,
    to,
    days,
    bucket,
    totalRevenue,
    totalProfit,
    totalCollected,
    totalOrders,
    prevRevenue,
    prevProfit,
    prevOrders,
    trend,
    weekday,
  ];
}
