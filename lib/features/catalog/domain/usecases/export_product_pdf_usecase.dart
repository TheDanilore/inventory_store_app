import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/pdf_generator_repository.dart';

@injectable
class ExportProductPdfUseCase {
  final PdfGeneratorRepository _pdfRepository;

  ExportProductPdfUseCase(this._pdfRepository);

  Future<Either<Failure, void>> call({
    required ProductEntity product,
    required List<ProductVariantEntity> variants,
    required Map<String, int> stockByVariant,
  }) async {
    try {
      await _pdfRepository.shareProduct(
        product,
        variants: variants,
        stockByVariant: stockByVariant,
      );
      return right(null);
    } catch (e) {
      return left(ServerFailure(message: e.toString()));
    }
  }
}
