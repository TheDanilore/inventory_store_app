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
    bool forceRefresh = false,
  }) async {
    return await repository.getBrands(
      activeOnly: activeOnly,
      forceRefresh: forceRefresh,
    );
  }

  List<BrandEntity>? getCached({bool activeOnly = false}) =>
      repository.getCachedBrands(activeOnly: activeOnly);
}
