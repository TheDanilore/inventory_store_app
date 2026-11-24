import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/system_diagnostics_entity.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/get_system_diagnostics_uc.dart';

abstract class SystemDiagnosticsState extends Equatable {
  final SystemDiagnosticsEntity? diagnostics;
  final bool isMeasuring;

  const SystemDiagnosticsState({this.diagnostics, this.isMeasuring = false});

  @override
  List<Object?> get props => [diagnostics, isMeasuring];
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

  @override
  List<Object?> get props => [message, diagnostics, isMeasuring];
}

/// Cubit global singleton para telemetría del sistema.
///
/// Garantiza experiencia Zero-Shimmer mediante caché L1 (RAM con TTL) y L2
/// (`SharedPreferences`), deduplicación de peticiones concurrentes in-flight
/// y trazabilidad explícita de errores sin `catch` silenciosos.
@lazySingleton
class SystemDiagnosticsCubit extends Cubit<SystemDiagnosticsState> {
  static const Duration cacheTtl = Duration(minutes: 5);
  static const String _tag = 'SystemDiagnosticsCubit';

  final GetSystemDiagnosticsUseCase _getDiagnosticsUc;
  Future<void>? _inFlight;

  SystemDiagnosticsCubit(this._getDiagnosticsUc)
    : super(_initialStateFromCache(_getDiagnosticsUc));

  static SystemDiagnosticsState _initialStateFromCache(
    GetSystemDiagnosticsUseCase useCase,
  ) {
    final cached = useCase.readMemoryCache();
    if (cached != null) {
      return SystemDiagnosticsLoaded(cached);
    }
    return const SystemDiagnosticsInitial();
  }

  /// Carga la telemetría del sistema garantizando Zero-Shimmer.
  ///
  /// - Si L1 está vigente dentro del [cacheTtl] y [forceRefresh] es false,
  ///   retorna de inmediato sin Egress ni rebuilds.
  /// - Si L1 expiró o no existe, hidrata L2 sin mostrar shimmer y revalida
  ///   silenciosamente en segundo plano.
  Future<void> loadDiagnostics({bool forceRefresh = false}) {
    final current = state.diagnostics ?? _getDiagnosticsUc.readMemoryCache();

    if (current != null && !forceRefresh) {
      final isFresh = DateTime.now().difference(current.measuredAt) < cacheTtl;
      if (isFresh) {
        if (state is SystemDiagnosticsInitial ||
            state is SystemDiagnosticsLoading) {
          emit(SystemDiagnosticsLoaded(current));
        }
        return Future.value();
      }
    }

    if (_inFlight != null && !forceRefresh) {
      return _inFlight!;
    }

    final future = _performLoad(
      initialCached: current,
      forceRefresh: forceRefresh,
    );
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  /// Medición puntual de latencia bajo demanda (sin timers periódicos en bucle).
  Future<void> measureLatency() {
    final current = state.diagnostics ?? _getDiagnosticsUc.readMemoryCache();
    if (current == null) {
      return loadDiagnostics(forceRefresh: true);
    }

    if (_inFlight != null) {
      return _inFlight!;
    }

    final future = _performLatencyOnly(current);
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  Future<void> _performLoad({
    required SystemDiagnosticsEntity? initialCached,
    required bool forceRefresh,
  }) async {
    var latest = initialCached;

    // 1. Hidratación L2 (Zero-Shimmer en arranque en frío / recarga F5).
    if (latest == null) {
      final l2 = await _getDiagnosticsUc.readPersistedCache();
      if (isClosed) return;
      if (l2 != null) {
        latest = l2;
        emit(SystemDiagnosticsLoaded(l2, isMeasuring: true));
      } else {
        emit(const SystemDiagnosticsLoading());
      }
    } else {
      emit(SystemDiagnosticsLoaded(latest, isMeasuring: true));
    }

    // 2. Medición remota real + obtención de versión de plataforma.
    try {
      final fresh = await _getDiagnosticsUc.fetchFresh(previous: latest);
      if (isClosed) return;
      emit(SystemDiagnosticsLoaded(fresh, isMeasuring: false));
    } on AppException catch (e, st) {
      await _emitFailureState(e, st, previous: latest);
    } catch (e, st) {
      await _emitFailureState(
        AppException(message: e.toString(), originalError: e),
        st,
        previous: latest,
      );
    }
  }

  Future<void> _performLatencyOnly(SystemDiagnosticsEntity current) async {
    emit(SystemDiagnosticsLoaded(current, isMeasuring: true));
    try {
      final updated = await _getDiagnosticsUc.measureLatencyOnly(current);
      if (isClosed) return;
      emit(SystemDiagnosticsLoaded(updated, isMeasuring: false));
    } on AppException catch (e, st) {
      await _emitFailureState(e, st, previous: current);
    } catch (e, st) {
      await _emitFailureState(
        AppException(message: e.toString(), originalError: e),
        st,
        previous: current,
      );
    }
  }

  Future<void> _emitFailureState(
    AppException error,
    StackTrace stackTrace, {
    required SystemDiagnosticsEntity? previous,
  }) async {
    LoggerService.w(
      'Fallo en diagnóstico del sistema: ${error.message}',
      tag: _tag,
      error: error,
      stackTrace: stackTrace,
    );

    var fallback = previous;
    if (fallback == null) {
      final pkg = await _getDiagnosticsUc.readPackageInfo();
      fallback = SystemDiagnosticsEntity(
        appVersion: pkg.version,
        buildNumber: pkg.buildNumber,
        latencyMs: null,
        isBackendReachable: false,
        measuredAt: DateTime.now(),
      );
    } else {
      fallback = fallback.copyWith(
        clearLatency: true,
        isBackendReachable: false,
        measuredAt: DateTime.now(),
      );
    }

    await _getDiagnosticsUc.persistFailureState(fallback);
    if (isClosed) return;
    emit(
      SystemDiagnosticsError(
        error.message,
        diagnostics: fallback,
        isMeasuring: false,
      ),
    );
  }
}
