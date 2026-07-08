import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/utils/result.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/data/models/business_info_model.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

class GetBusinessInfoUseCase extends UseCase<BusinessInfoModel?, NoParams> {
  final AppConfigRepository repository;

  GetBusinessInfoUseCase(this.repository);

  @override
  Future<Result<BusinessInfoModel?>> execute(NoParams params) async {
    try {
      try {
        final info = await repository.fetchBusinessInfo();
        return Success(info);
      } catch (remoteError) {
        final cached = await repository.fetchCachedBusinessInfo();
        if (cached != null) {
          return Success(cached);
        }
        return Error(Failure.from(remoteError));
      }
    } catch (e) {
      return Error(Failure.from(e));
    }
  }
}
