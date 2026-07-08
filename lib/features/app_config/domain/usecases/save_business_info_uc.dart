import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/utils/result.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/data/models/business_info_model.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

class SaveBusinessInfoUseCase extends UseCase<BusinessInfoModel, BusinessInfoModel> {
  final AppConfigRepository repository;

  SaveBusinessInfoUseCase(this.repository);

  @override
  Future<Result<BusinessInfoModel>> execute(BusinessInfoModel params) async {
    try {
      final savedInfo = await repository.saveBusinessInfo(params);
      await repository.cacheBusinessInfo(savedInfo);
      return Success(savedInfo);
    } catch (e) {
      return Error(Failure.from(e));
    }
  }
}
