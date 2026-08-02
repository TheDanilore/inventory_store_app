import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/data/utils/catalog_pdf_generator.dart';

@injectable
class ExportCatalogPdfUseCase {
  ExportCatalogPdfUseCase();

  Future<Either<Failure, void>> call({
    required List<ProductEntity> products,
  }) async {
    try {
      final variantsByProduct = {
        for (final p in products) p.id: p.productVariants,
      };
      final stockByVariant = <String, int>{};
      for (final p in products) {
        for (final batch in p.warehouseStockBatches) {
          if (batch.variantId.isNotEmpty) {
            stockByVariant[batch.variantId] =
                (stockByVariant[batch.variantId] ?? 0) +
                batch.availableQuantity.toInt();
          }
        }
        if (p.productVariants.length == 1) {
          final singleV = p.productVariants.first;
          if ((stockByVariant[singleV.id] ?? 0) == 0 && p.totalStock > 0) {
            stockByVariant[singleV.id] = p.totalStock;
          }
        }
      }
      await CatalogPdfGenerator.shareCatalog(
        products: products,
        variantsByProduct: variantsByProduct,
        stockByVariant: stockByVariant,
      );
      return right(null);
    } catch (e) {
      return left(ServerFailure(message: e.toString()));
    }
  }
}
