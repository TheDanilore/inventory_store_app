class SalesMetricsEntity {
  final int totalSales;
  final double totalRevenue;
  final double totalProfit;
  final double replacementFund;
  final double averageTicket;
  final double salesMargin;

  const SalesMetricsEntity({
    required this.totalSales,
    required this.totalRevenue,
    required this.totalProfit,
    required this.replacementFund,
    required this.averageTicket,
    required this.salesMargin,
  });

  factory SalesMetricsEntity.empty() {
    return const SalesMetricsEntity(
      totalSales: 0,
      totalRevenue: 0,
      totalProfit: 0,
      replacementFund: 0,
      averageTicket: 0,
      salesMargin: 0,
    );
  }
}
