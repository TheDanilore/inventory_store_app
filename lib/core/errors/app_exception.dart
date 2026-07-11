/// Excepción base de la aplicación.
///
/// Todas las excepciones de negocio deben extender esta clase
/// para que el sistema de manejo de errores pueda capturarlas
/// de forma uniforme.
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

/// Error de red: sin conexión o timeout.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Sin conexión a internet. Verifica tu red e intenta de nuevo.',
    super.code = 'NETWORK_ERROR',
    super.originalError,
  });
}

/// Error de servidor: respuesta 4xx / 5xx de Supabase / API.
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code = 'SERVER_ERROR',
    super.originalError,
  });
}

/// El recurso solicitado no fue encontrado (404).
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code = 'NOT_FOUND',
    super.originalError,
  });
}

/// El usuario no tiene permiso para realizar la acción.
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'No tienes permisos para realizar esta acción.',
    super.code = 'UNAUTHORIZED',
    super.originalError,
  });
}

/// Error de validación de datos de entrada.
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors,
    super.originalError,
  });
}

/// Error de stock insuficiente (específico de inventario y POS).
class InsufficientStockException extends AppException {
  final String productName;
  final int requested;
  final int available;

  const InsufficientStockException({
    required this.productName,
    required this.requested,
    required this.available,
    super.code = 'INSUFFICIENT_STOCK',
    super.originalError,
  }) : super(
         message:
             'Stock insuficiente para "$productName": '
             'solicitado $requested, disponible $available.',
       );
}

/// Error de caché local (SharedPreferences, Hive, SQLite).
class CacheException extends AppException {
  const CacheException({
    super.message = 'Error de lectura o escritura en el almacenamiento local.',
    super.code = 'CACHE_ERROR',
    super.originalError,
  });
}
