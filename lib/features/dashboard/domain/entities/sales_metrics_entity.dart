class SalesMetricsEntity {
  final int totalSales;
  final double totalRevenue;
  final double totalProfit;
  final double replacementFund;
  final double averageTicket;
  final double salesMargin;

  final List<Map<String, dynamic>> bestSellers;
  final List<Map<String, dynamic>> weeklyActivity;
  final String peakDayLabel;
  final List<double> revenueTrendPoints;

  const SalesMetricsEntity({
    required this.totalSales,
    required this.totalRevenue,
    required this.totalProfit,
    required this.replacementFund,
    required this.averageTicket,
    required this.salesMargin,
    this.bestSellers = const [],
    this.weeklyActivity = const [],
    this.peakDayLabel = 'Sin ventas',
    this.revenueTrendPoints = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  });

  factory SalesMetricsEntity.empty() {
    return const SalesMetricsEntity(
      totalSales: 0,
      totalRevenue: 0,
      totalProfit: 0,
      replacementFund: 0,
      averageTicket: 0,
      salesMargin: 0,
      bestSellers: [],
      weeklyActivity: [],
      peakDayLabel: 'Sin ventas',
      revenueTrendPoints: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    );
  }
}
