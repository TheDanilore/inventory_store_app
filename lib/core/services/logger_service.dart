import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

enum LogLevel { debug, info, warning, error }

/// Servicio centralizado de logging profesional para diagnóstico y QA.
/// Permite capturar contexto, errores y StackTrace garantizando que ningún
/// fallo pase desapercibido en consola o herramientas de monitoreo.
@lazySingleton
class LoggerService {
  const LoggerService();

  static void d(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void i(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void w(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void e(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace ?? StackTrace.current);
  }

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = tag != null ? '[$tag]' : '[APP]';
    final levelStr = level.name.toUpperCase();
    final logMessage = '$prefix [$levelStr] $message';

    final int levelValue = switch (level) {
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
    };

    developer.log(
      logMessage,
      name: 'InventoryStoreERP',
      level: levelValue,
      error: error,
      stackTrace: stackTrace,
    );

    if (kDebugMode && level == LogLevel.error && error != null) {
      developer.log('─── StackTrace: ───\n$stackTrace', name: 'InventoryStoreERP');
    }
  }

  void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      d(message, tag: tag, error: error, stackTrace: stackTrace);

  void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      i(message, tag: tag, error: error, stackTrace: stackTrace);

  void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      w(message, tag: tag, error: error, stackTrace: stackTrace);

  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) =>
      e(message, tag: tag, error: error, stackTrace: stackTrace);
}
