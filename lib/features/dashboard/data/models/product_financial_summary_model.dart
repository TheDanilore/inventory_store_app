import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

class ProductFinancialSummaryModel {
  final ProductVariantEntity variant;
  final double unitCost;
  final int stockQuantity;
  final double inventoryValue;
  final int soldQuantity;
  final double soldCost;
  final double soldRevenue;

  const ProductFinancialSummaryModel({
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
