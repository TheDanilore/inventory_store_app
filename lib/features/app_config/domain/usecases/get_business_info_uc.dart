import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/data/models/business_info_model.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@lazySingleton
class GetBusinessInfoUseCase extends UseCase<BusinessInfoModel?, NoParams> {
  final AppConfigRepository repository;

  GetBusinessInfoUseCase(this.repository);

  @override
  Future<Either<Failure, BusinessInfoModel?>> call(NoParams params) async {
    try {
      try {
        final info = await repository.fetchBusinessInfo();
        return right(info);
      } catch (remoteError) {
        final cached = await repository.fetchCachedBusinessInfo();
        if (cached != null) {
          return right(cached);
        }
        return left(Failure.from(remoteError));
      }
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
