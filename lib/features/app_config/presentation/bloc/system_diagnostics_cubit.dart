import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/system_diagnostics_entity.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SystemDiagnosticsState {
  final SystemDiagnosticsEntity? diagnostics;
  final bool isMeasuring;

  const SystemDiagnosticsState({this.diagnostics, this.isMeasuring = false});
}

class SystemDiagnosticsInitial extends SystemDiagnosticsState {
  const SystemDiagnosticsInitial() : super();
}

class SystemDiagnosticsLoading extends SystemDiagnosticsState {
  const SystemDiagnosticsLoading({super.diagnostics})
    : super(isMeasuring: true);
}

class SystemDiagnosticsLoaded extends SystemDiagnosticsState {
  const SystemDiagnosticsLoaded(
    SystemDiagnosticsEntity diagnostics, {
    super.isMeasuring = false,
  }) : super(diagnostics: diagnostics);
}

class SystemDiagnosticsError extends SystemDiagnosticsState {
  final String message;

  const SystemDiagnosticsError(
    this.message, {
    super.diagnostics,
    super.isMeasuring = false,
  });
}

@lazySingleton
class SystemDiagnosticsCubit extends Cubit<SystemDiagnosticsState> {
  SystemDiagnosticsCubit() : super(const SystemDiagnosticsInitial());

  /// Carga la telemetría del sistema garantizando Zero-Shimmer (SWR en memoria).
  /// Si ya existe un estado previo y [forceRefresh] es false, no emite Loading
  /// y conserva los datos en pantalla de inmediato.
  Future<void> loadDiagnostics({bool forceRefresh = false}) async {
    final current = state.diagnostics;
    if (current != null && !forceRefresh) {
      return; // Retorno inmediato: datos ya en memoria, 0ms de shimmer
    }

    if (current == null) {
      emit(const SystemDiagnosticsLoading());
    } else {
      emit(SystemDiagnosticsLoaded(current, isMeasuring: true));
    }

    try {
      String version = current?.appVersion ?? 'Cargando...';
      String build = current?.buildNumber ?? '';

      try {
        final info = await PackageInfo.fromPlatform();
        version = info.version;
        build = info.buildNumber;
      } catch (_) {
        if (version == 'Cargando...') version = 'Desconocida';
      }

      final latencyResult = await _pingBackend();

      final updated = SystemDiagnosticsEntity(
        appVersion: version,
        buildNumber: build,
        latencyMs: latencyResult.latencyMs,
        isBackendReachable: latencyResult.isReachable,
        measuredAt: DateTime.now(),
      );

      emit(SystemDiagnosticsLoaded(updated, isMeasuring: false));
    } catch (e) {
      emit(
        SystemDiagnosticsError(
          'Error al obtener diagnóstico: $e',
          diagnostics: current,
          isMeasuring: false,
        ),
      );
    }
  }

  /// Medición puntual de latencia bajo demanda (sin timers periódicos en bucle).
  Future<void> measureLatency() async {
    final current = state.diagnostics;
    if (current == null) {
      await loadDiagnostics(forceRefresh: true);
      return;
    }

    emit(SystemDiagnosticsLoaded(current, isMeasuring: true));

    final pingResult = await _pingBackend();
    final updated = current.copyWith(
      latencyMs: pingResult.latencyMs,
      isBackendReachable: pingResult.isReachable,
      measuredAt: DateTime.now(),
    );

    emit(SystemDiagnosticsLoaded(updated, isMeasuring: false));
  }

  Future<({int? latencyMs, bool isReachable})> _pingBackend() async {
    try {
      final stopwatch = Stopwatch()..start();
      await Supabase.instance.client
          .from('app_settings')
          .select('key')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      return (latencyMs: stopwatch.elapsedMilliseconds, isReachable: true);
    } catch (_) {
      return (latencyMs: null, isReachable: false);
    }
  }
}
