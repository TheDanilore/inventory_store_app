import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_current_profile_id_usecase.dart';

@lazySingleton
class SaveProductMasterUseCase {
  final ProductsRepository repository;
  SaveProductMasterUseCase(this.repository);

  Future<Either<Failure, String>> call(
    ProductEntity product,
    String? profileId,
  ) {
    return repository.saveProductMaster(product, profileId);
  }
}

@lazySingleton
class CatalogFormMutationsUC {
  final ProductsRepository repository;
  final GetCurrentProfileIdUseCase getProfileId;

  CatalogFormMutationsUC(this.repository, this.getProfileId);

  Future<Either<Failure, String>> call({
    required String productId,
    required Map<String, dynamic> variantData,
    String? variantId,
  }) async {
    final pIdRes = await getProfileId();
    final profileId = pIdRes.fold((l) => null, (r) => r);

    return repository.saveVariant(
      productId: productId,
      variantData: variantData,
      variantId: variantId,
      profileId: profileId,
    );
  }
}

@lazySingleton
class SaveVariantUC {
  final ProductsRepository repository;
  final GetCurrentProfileIdUseCase getProfileId;
  SaveVariantUC(this.repository, this.getProfileId);

  Future<Either<Failure, String>> call({
    required String productId,
    required Map<String, dynamic> variantData,
    String? variantId,
  }) async {
    final pIdRes = await getProfileId();
    final profileId = pIdRes.fold((l) => null, (r) => r);

    return repository.saveVariant(
      productId: productId,
      variantData: variantData,
      variantId: variantId,
      profileId: profileId,
    );
  }
}

@lazySingleton
class SaveVariantAttributesUC {
  final ProductsRepository repository;
  SaveVariantAttributesUC(this.repository);

  Future<Either<Failure, void>> call(
    String variantId,
    List<String> attributeValueIds,
  ) {
    return repository.saveVariantAttributes(variantId, attributeValueIds);
  }
}

@lazySingleton
class GetFirstVariantIdUC {
  final ProductsRepository repository;
  GetFirstVariantIdUC(this.repository);

  Future<Either<Failure, String?>> call(String productId) {
    return repository.getFirstVariantId(productId);
  }
}

@lazySingleton
class SetProductActiveUC {
  final ProductsRepository repository;
  SetProductActiveUC(this.repository);

  Future<Either<Failure, void>> call(String productId, bool isActive) {
    return repository.setProductActive(
      productId: productId,
      isActive: isActive,
    );
  }
}

@lazySingleton
class ClearCatalogCacheUC {
  final ProductsRepository repository;
  ClearCatalogCacheUC(this.repository);

  Future<void> call() {
    return repository.clearCache();
  }
}
