import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';

abstract class BrandsRepository {
  Future<Either<Failure, BrandEntity>> createBrand({
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    required bool isActive,
    String? profileId,
  });

  Future<Either<Failure, void>> updateBrand({
    required String id,
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    required bool isActive,
    String? profileId,
  });

  Future<Either<Failure, void>> deleteBrand(String id);

  Future<Either<Failure, List<BrandEntity>>> getBrands({
    bool activeOnly = false,
  });
}
