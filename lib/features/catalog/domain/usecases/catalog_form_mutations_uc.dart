import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class SaveProductMasterUC {
  final CatalogRepository repository;
  SaveProductMasterUC(this.repository);

  Future<Either<Failure, String>> call(ProductEntity product, String? profileId) {
    return repository.saveProductMaster(product, profileId);
  }
}

@lazySingleton
class SaveVariantUC {
  final CatalogRepository repository;
  SaveVariantUC(this.repository);

  Future<Either<Failure, String>> call({required String productId, required Map<String, dynamic> variantData, String? variantId}) {
    return repository.saveVariant(productId: productId, variantData: variantData, variantId: variantId);
  }
}

@lazySingleton
class SaveVariantAttributesUC {
  final CatalogRepository repository;
  SaveVariantAttributesUC(this.repository);

  Future<Either<Failure, void>> call(String variantId, List<String> attributeValueIds) {
    return repository.saveVariantAttributes(variantId, attributeValueIds);
  }
}

@lazySingleton
class GetFirstVariantIdUC {
  final CatalogRepository repository;
  GetFirstVariantIdUC(this.repository);

  Future<Either<Failure, String?>> call(String productId) {
    return repository.getFirstVariantId(productId);
  }
}
