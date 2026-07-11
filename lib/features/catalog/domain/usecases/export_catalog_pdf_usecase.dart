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
      await CatalogPdfGenerator.shareCatalog(
        products: products,
        variantsByProduct: const {},
        stockByVariant: const {},
      );
      return right(null);
    } catch (e) {
      return left(ServerFailure(message: e.toString()));
    }
  }
}