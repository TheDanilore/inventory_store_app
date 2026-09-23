import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/brands_repository.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_current_profile_id_usecase.dart';

@lazySingleton
class CreateBrandUseCase {
  final BrandsRepository repository;
  final GetCurrentProfileIdUseCase getProfileId;

  CreateBrandUseCase(this.repository, this.getProfileId);

  Future<Either<Failure, BrandEntity>> call({
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    required bool isActive,
  }) async {
    final pIdRes = await getProfileId();
    final profileId = pIdRes.fold((l) => null, (r) => r);

    return await repository.createBrand(
      name: name,
      description: description,
      logoUrl: logoUrl,
      website: website,
      isActive: isActive,
      profileId: profileId,
    );
  }
}

@lazySingleton
class UpdateBrandUC {
  final BrandsRepository repository;
  final GetCurrentProfileIdUseCase getProfileId;

  UpdateBrandUC(this.repository, this.getProfileId);

  Future<Either<Failure, void>> call({
    required String id,
    required String name,
    String? description,
    String? logoUrl,
    String? website,
    required bool isActive,
  }) async {
    final pIdRes = await getProfileId();
    final profileId = pIdRes.fold((l) => null, (r) => r);

    return await repository.updateBrand(
      id: id,
      name: name,
      description: description,
      logoUrl: logoUrl,
      website: website,
      isActive: isActive,
      profileId: profileId,
    );
  }
}

@lazySingleton
class DeleteBrandUC {
  final BrandsRepository repository;

  DeleteBrandUC(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteBrand(id);
  }
}
