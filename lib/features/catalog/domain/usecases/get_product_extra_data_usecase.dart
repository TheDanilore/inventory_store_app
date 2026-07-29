import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

typedef ProductExtraData =
    ({
      List<Map<String, dynamic>> stocks,
      List<Map<String, dynamic>> batches,
      List<ProductImageEntity> images,
      List<ProductVariantEntity> variants,
      List<Map<String, dynamic>> reviews,
      List<Map<String, dynamic>> ingredients,
    });

@lazySingleton
class GetProductExtraDataUseCase {
  final ProductsRepository repository;

  GetProductExtraDataUseCase(this.repository);

  Future<Either<Failure, ProductExtraData>> call(String productId) {
    return repository.fetchProductExtraData(productId);
  }
}
