import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/pdf_generator_repository.dart';

@injectable
class ExportCatalogPdfUseCase {
  final PdfGeneratorRepository _pdfRepository;

  ExportCatalogPdfUseCase(this._pdfRepository);

  Future<Either<Failure, void>> call({
    required List<ProductEntity> products,
  }) async {
    try {
      await _pdfRepository.shareCatalog(
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