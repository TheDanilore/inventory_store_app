import 'package:inventory_store_app/models/product_variant_model.dart';

class VariantFinancialSummary {
  final ProductVariantModel variant;
  final double unitCost;
  final int stockQuantity;
  final double inventoryValue;
  final int soldQuantity;
  final double soldCost;
  final double soldRevenue;

  const VariantFinancialSummary({
    required this.variant,
    required this.unitCost,
    required this.stockQuantity,
    required this.inventoryValue,
    required this.soldQuantity,
    required this.soldCost,
    required this.soldRevenue,
  });

  double get soldProfit => soldRevenue - soldCost;
}
