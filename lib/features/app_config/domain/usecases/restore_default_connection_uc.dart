import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@injectable
class RestoreDefaultConnectionUseCase implements UseCase<void, NoParams> {
  final AppConfigRepository repository;
  RestoreDefaultConnectionUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    try {
      await repository.restoreDefaultConnection();
      return right(null);
    } catch (e) {
      return left(Failure.from('Error al restaurar conexión por defecto'));
    }
  }
}
