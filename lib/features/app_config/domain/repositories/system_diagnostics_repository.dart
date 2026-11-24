import 'package:inventory_store_app/features/app_config/domain/entities/system_diagnostics_entity.dart';

/// Contrato de repositorio para telemetría del sistema y caché L1/L2 Zero-Shimmer.
abstract class SystemDiagnosticsRepository {
  /// Lee la última telemetría almacenada en memoria RAM (L1).
  SystemDiagnosticsEntity? getCachedL1();

  /// Lee la última telemetría persistida en almacenamiento local (L2).
  Future<SystemDiagnosticsEntity?> getCachedL2();

  /// Persiste la telemetría en memoria L1 y almacenamiento local L2.
  Future<void> saveCache(SystemDiagnosticsEntity entity);

  /// Obtiene la versión y build de la aplicación desde la plataforma.
  Future<({String version, String buildNumber})> getPackageInfo();

  /// Mide el RTT hacia Supabase ejecutando una consulta mínima sin payload JSON.
  Future<({int? latencyMs, bool isReachable})> pingBackend({
    Duration timeout = const Duration(seconds: 5),
  });
}
