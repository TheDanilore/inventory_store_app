import 'package:inventory_store_app/core/errors/failure.dart';

/// Un tipo `Result` simple inspirado en Rust/Swift para manejo de errores funcional.
///
/// Permite devolver explícitamente un [Failure] o un valor de tipo [T].
/// Usa [fold] para manejar ambos casos de forma segura.
sealed class Result<T> {
  const Result();

  /// Ejecuta [onFailure] si el resultado es un error, o [onSuccess] si fue exitoso.
  R fold<R>(R Function(Failure failure) onFailure, R Function(T data) onSuccess);
}

/// Representa un resultado exitoso.
final class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  R fold<R>(R Function(Failure failure) onFailure, R Function(T data) onSuccess) {
    return onSuccess(data);
  }
}

/// Representa un resultado fallido.
final class Error<T> extends Result<T> {
  final Failure failure;

  const Error(this.failure);

  @override
  R fold<R>(R Function(Failure failure) onFailure, R Function(T data) onSuccess) {
    return onFailure(failure);
  }
}
