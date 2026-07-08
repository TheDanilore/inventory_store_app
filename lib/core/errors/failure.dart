import 'package:inventory_store_app/core/errors/app_exception.dart';

/// Representa un fallo en la capa de dominio.
///
/// Los [Failure]s son el resultado "fallido" tipado que los repositorios
/// y usecases devuelven en lugar de lanzar excepciones directamente.
/// Esto hace que el código de presentación pueda hacer pattern matching
/// sobre el tipo de fallo sin necesidad de try/catch.
sealed class Failure {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  /// Crea el [Failure] apropiado a partir de cualquier excepción.
  factory Failure.from(Object error) {
    if (error is NetworkException) return NetworkFailure(message: error.message);
    if (error is ServerException) return ServerFailure(message: error.message, code: error.code);
    if (error is NotFoundException) return NotFoundFailure(message: error.message);
    if (error is UnauthorizedException) return UnauthorizedFailure();
    if (error is ValidationException) {
      return ValidationFailure(message: error.message, fieldErrors: error.fieldErrors);
    }
    if (error is InsufficientStockException) {
      return StockFailure(
        message: error.message,
        productName: error.productName,
        requested: error.requested,
        available: error.available,
      );
    }
    if (error is AppException) return ServerFailure(message: error.message, code: error.code);
    return UnexpectedFailure(message: error.toString());
  }

  @override
  String toString() => '$runtimeType(message: $message)';
}

/// Fallo de red — sin conexión o timeout.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Sin conexión a internet. Verifica tu red e intenta de nuevo.',
    super.code = 'NETWORK_ERROR',
  });
}

/// Fallo de servidor — respuesta de error de Supabase / API.
final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code = 'SERVER_ERROR'});
}

/// El recurso no fue encontrado.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message, super.code = 'NOT_FOUND'});
}

/// El usuario no tiene permisos.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure()
      : super(
          message: 'No tienes permisos para realizar esta acción.',
          code: 'UNAUTHORIZED',
        );
}

/// Error de validación de datos.
final class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;
  const ValidationFailure({
    required super.message,
    this.fieldErrors,
    super.code = 'VALIDATION_ERROR',
  });
}

/// Stock insuficiente para completar la operación.
final class StockFailure extends Failure {
  final String productName;
  final int requested;
  final int available;

  const StockFailure({
    required super.message,
    required this.productName,
    required this.requested,
    required this.available,
    super.code = 'INSUFFICIENT_STOCK',
  });
}

/// Fallo inesperado no categorizado.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.code = 'UNEXPECTED'});
}
