import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/utils/result.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@lazySingleton
class GetAppSettingsUseCase extends UseCase<Map<String, double>, NoParams> {
  final AppConfigRepository repository;

  GetAppSettingsUseCase(this.repository);

  @override
  Future<Result<Map<String, double>>> execute(NoParams params) async {
    try {
      // Intentar obtener de remoto
      try {
        final settings = await repository.fetchAppSettings();
        return Success(settings);
      } catch (remoteError) {
        // Fallback a caché
        final cached = await repository.fetchCachedSettings();
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
