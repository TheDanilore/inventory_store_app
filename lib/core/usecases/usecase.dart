import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';

/// Caso de Uso asíncrono genérico.
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Caso de Uso síncrono genérico.
abstract class SyncUseCase<T, Params> {
  Either<Failure, T> call(Params params);
}

/// Representa la ausencia de parámetros para un Caso de Uso.
class NoParams {
  const NoParams();
}
