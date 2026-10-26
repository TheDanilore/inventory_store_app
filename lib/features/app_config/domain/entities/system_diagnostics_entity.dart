/// Entidad inmutable que representa la telemetría, latencia y versión del sistema ERP.
class SystemDiagnosticsEntity {
  final String appVersion;
  final String buildNumber;
  final int? latencyMs;
  final bool isBackendReachable;
  final DateTime measuredAt;

  const SystemDiagnosticsEntity({
    required this.appVersion,
    required this.buildNumber,
    this.latencyMs,
    required this.isBackendReachable,
    required this.measuredAt,
  });

  bool get isHealthy => isBackendReachable && (latencyMs ?? 999) < 600;

  String get versionDisplay =>
      buildNumber.isNotEmpty
          ? 'DANILORE ONE ERP v$appVersion (Build $buildNumber)'
          : 'DANILORE ONE ERP v$appVersion';

  String get latencyText {
    if (latencyMs == null) {
      return isBackendReachable ? 'N/D' : 'Error de conexión';
    }
    final ms = latencyMs!;
    final quality =
        ms < 100
            ? 'Excelente'
            : ms < 300
            ? 'Bueno'
            : ms < 600
            ? 'Regular'
            : 'Lento';
    return '$ms ms ($quality)';
  }

  SystemDiagnosticsEntity copyWith({
    String? appVersion,
    String? buildNumber,
    int? latencyMs,
    bool? isBackendReachable,
    DateTime? measuredAt,
  }) {
    return SystemDiagnosticsEntity(
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      latencyMs: latencyMs ?? this.latencyMs,
      isBackendReachable: isBackendReachable ?? this.isBackendReachable,
      measuredAt: measuredAt ?? this.measuredAt,
    );
  }
}
