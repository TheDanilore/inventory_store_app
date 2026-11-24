import 'package:equatable/equatable.dart';

/// Entidad inmutable que representa la telemetría, latencia y versión del sistema ERP.
class SystemDiagnosticsEntity extends Equatable {
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

  /// Genera un reporte unificado de diagnóstico listo para soporte técnico.
  String buildDiagnosticReport({required bool isOnline}) {
    final latencyPart = latencyMs != null ? '${latencyMs}ms' : 'N/D';
    final networkPart = isOnline ? 'Online' : 'Offline';
    final backendPart = isBackendReachable ? 'Reachable' : 'Unreachable';
    return '$versionDisplay | Latency: $latencyPart | DB: PostgreSQL Supabase | Network: $networkPart | Supabase: $backendPart';
  }

  SystemDiagnosticsEntity copyWith({
    String? appVersion,
    String? buildNumber,
    int? latencyMs,
    bool clearLatency = false,
    bool? isBackendReachable,
    DateTime? measuredAt,
  }) {
    return SystemDiagnosticsEntity(
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      latencyMs: clearLatency ? null : (latencyMs ?? this.latencyMs),
      isBackendReachable: isBackendReachable ?? this.isBackendReachable,
      measuredAt: measuredAt ?? this.measuredAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'app_version': appVersion,
    'build_number': buildNumber,
    'latency_ms': latencyMs,
    'is_backend_reachable': isBackendReachable,
    'measured_at': measuredAt.toIso8601String(),
  };

  factory SystemDiagnosticsEntity.fromJson(Map<String, dynamic> json) {
    return SystemDiagnosticsEntity(
      appVersion: json['app_version'] as String? ?? '1.0.0',
      buildNumber: json['build_number'] as String? ?? '',
      latencyMs: (json['latency_ms'] as num?)?.toInt(),
      isBackendReachable: json['is_backend_reachable'] as bool? ?? false,
      measuredAt:
          DateTime.tryParse(json['measured_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  List<Object?> get props => [
    appVersion,
    buildNumber,
    latencyMs,
    isBackendReachable,
    measuredAt,
  ];
}
