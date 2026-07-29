import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@lazySingleton
class GetAppSettingsUseCase extends UseCase<Map<String, double>, NoParams> {
  final AppConfigRepository repository;

  GetAppSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, double>>> call(NoParams params) async {
    try {
      // Intentar obtener de remoto
      try {
        final settings = await repository.fetchAppSettings();
        return right(settings);
      } catch (remoteError) {
        // Fallback a caché
        final cached = await repository.fetchCachedSettings();
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
