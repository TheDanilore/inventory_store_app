import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@lazySingleton
class GetBusinessInfoUseCase extends UseCase<BusinessInfoEntity?, NoParams> {
  final AppConfigRepository repository;

  GetBusinessInfoUseCase(this.repository);

  @override
  Future<Either<Failure, BusinessInfoEntity?>> call(NoParams params) async {
    try {
      try {
        final info = await repository.fetchBusinessInfo();
        return right(info);
      } catch (remoteError, st) {
        LoggerService.w(
          'Error remoto al obtener información del negocio, intentando caché',
          tag: 'GetBusinessInfoUseCase',
          error: remoteError,
          stackTrace: st,
        );
        final cached = await repository.fetchCachedBusinessInfo();
        if (cached != null) {
          return right(cached);
        }
        return left(Failure.from(remoteError));
      }
    } catch (e, st) {
      LoggerService.e(
        'Error crítico al obtener información del negocio',
        tag: 'GetBusinessInfoUseCase',
        error: e,
        stackTrace: st,
      );
      return left(Failure.from(e));
    }
  }
}
