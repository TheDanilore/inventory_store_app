import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@lazySingleton
class GetConnectionUrlUseCase extends UseCase<String?, NoParams> {
  final AppConfigRepository repository;

  GetConnectionUrlUseCase(this.repository);

  @override
  Future<Either<Failure, String?>> call(NoParams params) async {
    try {
      final url = await repository.getConnectionUrl();
      return right(url);
    } catch (e) {
      return left(Failure.from('Error al obtener la URL de conexión: $e'));
    }
  }
}
