import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/brands_repository.dart';

@lazySingleton
class GetBrandsUC {
  final BrandsRepository repository;

  GetBrandsUC(this.repository);

  Future<Either<Failure, List<BrandEntity>>> call({
    bool activeOnly = false,
  }) async {
    return await repository.getBrands(activeOnly: activeOnly);
  }
}
