import 'package:inventory_store_app/core/utils/result.dart';

/// Clase base para todos los Use Cases de la aplicación.
///
/// Convención:
///   [T]      → tipo del resultado exitoso que devuelve el use case.
///   [Params] → parámetros de entrada. Usa [NoParams] si no se necesitan.
///
/// Ejemplo de uso:
/// ```dart
/// class GetCartTotalUseCase extends UseCase<double, List<CartItemEntity>> {
///   final PosRepository repository;
///   GetCartTotalUseCase(this.repository);
///
///   @override
///   Future<Result<double>> execute(List<CartItemEntity> params) async {
///     try {
///       final total = params.fold(0.0, (sum, item) => sum + item.subtotal);
///       return Success(total);
///     } catch (e) {
///       return Error(Failure.from(e));
///     }
///   }
/// }
/// ```
abstract class UseCase<T, Params> {
  Future<Result<T>> execute(Params params);
}

/// Clase base para Use Cases síncronos.
abstract class SyncUseCase<T, Params> {
  Result<T> execute(Params params);
}

/// Parámetro vacío para Use Cases que no necesitan input.
class NoParams {
  const NoParams();
}
