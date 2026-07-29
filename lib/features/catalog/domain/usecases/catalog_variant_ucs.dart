import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@lazySingleton
class GetVariantByIdUC {
  final ProductsRepository repository;
  GetVariantByIdUC(this.repository);
  Future<Either<Failure, ProductVariantEntity?>> call(String variantId) async {
    return await repository.getVariantById(variantId);
  }
}

@lazySingleton
class GetStockByVariantUC {
  final ProductsRepository repository;
  GetStockByVariantUC(this.repository);
  Future<Either<Failure, Map<String, int>>> call(String productId) async {
    return await repository.getStockByVariant(productId);
  }
}

@lazySingleton
class GetVariantsDraftsUC {
  final ProductsRepository repository;
  GetVariantsDraftsUC(this.repository);
  Future<Either<Failure, List<VariantDraftEntity>>> call(
    String productId,
  ) async {
    return await repository.getVariantsDrafts(productId);
  }
}

@lazySingleton
class DeleteVariantUC {
  final ProductsRepository repository;
  DeleteVariantUC(this.repository);
  Future<Either<Failure, void>> call(String variantId) async {
    return await repository.deleteVariant(variantId);
  }
}

@lazySingleton
class DeactivateVariantUC {
  final ProductsRepository repository;
  DeactivateVariantUC(this.repository);
  Future<Either<Failure, void>> call(String variantId) async {
    return await repository.deactivateVariant(variantId);
  }
}

@lazySingleton
class HasVariantSalesUC {
  final ProductsRepository repository;
  HasVariantSalesUC(this.repository);
  Future<Either<Failure, bool>> call(String variantId) async {
    return await repository.hasVariantSales(variantId);
  }
}
