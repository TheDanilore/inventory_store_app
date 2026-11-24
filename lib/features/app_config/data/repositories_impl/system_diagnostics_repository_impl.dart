import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/system_diagnostics_entity.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/system_diagnostics_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementación de [SystemDiagnosticsRepository] con caché L1 en memoria,
/// persistencia L2 en [SharedPreferences] y ping ligero HEAD hacia Supabase.
@LazySingleton(as: SystemDiagnosticsRepository)
class SystemDiagnosticsRepositoryImpl implements SystemDiagnosticsRepository {
  static const String _cacheKey = 'cached_system_diagnostics_v1';
  static const String _tag = 'SystemDiagnosticsRepo';

  final SupabaseClient _supabase;
  SystemDiagnosticsEntity? _l1Cache;
  ({String version, String buildNumber})? _packageInfoCache;

  SystemDiagnosticsRepositoryImpl(this._supabase);

  @override
  SystemDiagnosticsEntity? getCachedL1() => _l1Cache;

  @override
  Future<SystemDiagnosticsEntity?> getCachedL2() async {
    if (_l1Cache != null) return _l1Cache;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final entity = SystemDiagnosticsEntity.fromJson(decoded);
        _l1Cache = entity;
        return entity;
      }
      if (decoded is Map) {
        final entity = SystemDiagnosticsEntity.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        _l1Cache = entity;
        return entity;
      }
      return null;
    } catch (e, st) {
      LoggerService.w(
        'Fallo al leer telemetría de caché L2',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Future<void> saveCache(SystemDiagnosticsEntity entity) async {
    _l1Cache = entity;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(entity.toJson()));
    } catch (e, st) {
      LoggerService.w(
        'Fallo al guardar telemetría en caché L2',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<({String version, String buildNumber})> getPackageInfo() async {
    if (_packageInfoCache != null) return _packageInfoCache!;
    try {
      final info = await PackageInfo.fromPlatform();
      final resolved = (version: info.version, buildNumber: info.buildNumber);
      _packageInfoCache = resolved;
      return resolved;
    } catch (e, st) {
      LoggerService.w(
        'No se pudo obtener PackageInfo; usando fallback local',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      return (version: '1.0.0', buildNumber: '');
    }
  }

  @override
  Future<({int? latencyMs, bool isReachable})> pingBackend({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      // HEAD request sin body JSON (0 bytes de egress de filas).
      await _supabase
          .from('app_settings')
          .count(CountOption.planned)
          .timeout(timeout);
      stopwatch.stop();
      return (latencyMs: stopwatch.elapsedMilliseconds, isReachable: true);
    } on PostgrestException catch (e, st) {
      stopwatch.stop();
      LoggerService.w(
        'Error Postgrest en ping de diagnóstico: ${e.message}',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: e.message, originalError: e);
    } on TimeoutException catch (e, st) {
      stopwatch.stop();
      LoggerService.w(
        'Timeout en ping de diagnóstico hacia Supabase',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      throw NetworkException(
        message: 'Tiempo de espera agotado al conectar con Supabase.',
        originalError: e,
      );
    } on SocketException catch (e, st) {
      stopwatch.stop();
      LoggerService.w(
        'Error de socket en ping de diagnóstico',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      throw NetworkException(originalError: e);
    } on http.ClientException catch (e, st) {
      stopwatch.stop();
      LoggerService.w(
        'Error HTTP de cliente en ping de diagnóstico',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      throw NetworkException(originalError: e);
    } catch (e, st) {
      stopwatch.stop();
      LoggerService.e(
        'Error inesperado en ping de diagnóstico',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }
}
