import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

abstract class PdfGeneratorRepository {
  Future<void> shareCatalog({
    required List<ProductEntity> products,
    required Map<String, List<ProductVariantEntity>> variantsByProduct,
    required Map<String, int> stockByVariant,
  });

  Future<void> shareProduct(
    ProductEntity product, {
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  });
}