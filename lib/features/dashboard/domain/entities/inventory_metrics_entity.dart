class InventoryMetricsEntity {
  final int totalStock;
  final int lowStockProducts;
  final double totalInvestment;
  final double retailValue;
  final double grossProfit;
  final double expectedMaxProfit;
  final double expectedMinProfit;
  final double grossMargin;
  final int totalProducts;

  const InventoryMetricsEntity({
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

  factory InventoryMetricsEntity.empty() {
    return const InventoryMetricsEntity(
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
