import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/system_diagnostics_entity.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/system_diagnostics_repository.dart';

/// Caso de uso para leer caché L1/L2 de telemetría y ejecutar mediciones contra el backend.
@lazySingleton
class GetSystemDiagnosticsUseCase {
  final SystemDiagnosticsRepository _repository;

  const GetSystemDiagnosticsUseCase(this._repository);

  SystemDiagnosticsEntity? readMemoryCache() => _repository.getCachedL1();

  Future<SystemDiagnosticsEntity?> readPersistedCache() =>
      _repository.getCachedL2();

  Future<({String version, String buildNumber})> readPackageInfo() =>
      _repository.getPackageInfo();

  /// Obtiene la telemetría completa (versión + latencia) y actualiza L1/L2.
  Future<SystemDiagnosticsEntity> fetchFresh({
    SystemDiagnosticsEntity? previous,
  }) async {
    final pkg =
        (previous != null &&
                previous.appVersion.isNotEmpty &&
                previous.appVersion != 'Cargando...')
            ? (version: previous.appVersion, buildNumber: previous.buildNumber)
            : await _repository.getPackageInfo();

    final ping = await _repository.pingBackend();
    final entity = SystemDiagnosticsEntity(
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      latencyMs: ping.latencyMs,
      isBackendReachable: ping.isReachable,
      measuredAt: DateTime.now(),
    );

    await _repository.saveCache(entity);
    return entity;
  }

  /// Actualiza únicamente la latencia sobre una entidad ya hidratada y persiste L1/L2.
  Future<SystemDiagnosticsEntity> measureLatencyOnly(
    SystemDiagnosticsEntity current,
  ) async {
    final ping = await _repository.pingBackend();
    final updated = current.copyWith(
      latencyMs: ping.latencyMs,
      clearLatency: ping.latencyMs == null,
      isBackendReachable: ping.isReachable,
      measuredAt: DateTime.now(),
    );
    await _repository.saveCache(updated);
    return updated;
  }

  Future<void> persistFailureState(SystemDiagnosticsEntity entity) =>
      _repository.saveCache(entity);
}
