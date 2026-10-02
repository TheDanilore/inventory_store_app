import 'package:injectable/injectable.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/data/models/business_info_model.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/app_setting_entity.dart';
import 'package:inventory_store_app/features/app_config/data/models/app_setting_model.dart';

import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

@LazySingleton(as: AppConfigRepository)
class AppConfigRepositoryImpl implements AppConfigRepository {
  final SupabaseClient _supabase;
  static const String _settingsCacheKey = 'cached_app_settings';
  static const String _businessInfoCacheKey = 'cached_business_info';

  AppConfigRepositoryImpl(this._supabase);

  // --- App Settings ---

  @override
  Future<Map<String, double>> fetchAppSettings() async {
    try {
      final response =
          await _supabase.from('app_settings').select('key, value');

      final values = <String, double>{};
      for (final item in List<Map<String, dynamic>>.from(response)) {
        final key = item['key'] as String?;
        final value = item['value'];
        if (key != null && value != null) {
          values[key] = (value as num).toDouble();
        }
      }
      return values;
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error Postgrest al obtener app_settings: ${e.message}',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.message, originalError: e);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al obtener app_settings',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }

  @override
  Future<Map<String, double>?> fetchCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_settingsCacheKey);
      if (cachedString == null) return null;

      final List decoded = jsonDecode(cachedString);
      final values = <String, double>{};
      for (final item in decoded) {
        final key = item['key'] as String?;
        final value = item['value'];
        if (key != null && value != null) {
          values[key] = (value as num).toDouble();
        }
      }
      return values;
    } catch (e, st) {
      LoggerService.w(
        'Fallo al leer app_settings de caché',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<void> cacheAppSettings(List<Map<String, dynamic>> rawData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsCacheKey, jsonEncode(rawData));
    } catch (e, st) {
      LoggerService.w(
        'Fallo al guardar app_settings en caché',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<void> upsertAppSettings(List<AppSettingEntity> settings) async {
    if (settings.isEmpty) return;
    try {
      final payloadList =
          settings.map((e) => AppSettingModel.fromEntity(e).toMap()).toList();
      await _supabase
          .from('app_settings')
          .upsert(payloadList, onConflict: 'key');
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error Postgrest al guardar app_settings: ${e.message}',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.message, originalError: e);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al guardar app_settings',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }

  // --- Business Info ---

  @override
  Future<BusinessInfoEntity?> fetchBusinessInfo() async {
    try {
      final rawResponse = await _supabase
          .from('business_info')
          .select(
            'id, business_name, tax_id, address, phone, logo_url, loyalty_global_enabled, loyalty_customer_visible',
          )
          .order('updated_at', ascending: false)
          .limit(1);

      if (rawResponse.isNotEmpty) {
        final entity =
            BusinessInfoModel.fromMap(rawResponse.first).toEntity();
        await cacheBusinessInfo(entity);
        return entity;
      }
      return null;
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error Postgrest al obtener business_info: ${e.message}',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.message, originalError: e);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al obtener business_info',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }

  @override
  Future<BusinessInfoEntity?> fetchCachedBusinessInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(_businessInfoCacheKey);
      if (cachedString == null) return null;

      final decoded = jsonDecode(cachedString);
      Map<String, dynamic>? cached;
      if (decoded is Map) {
        cached = Map<String, dynamic>.from(decoded);
      } else if (decoded is List && decoded.isNotEmpty) {
        cached = Map<String, dynamic>.from(decoded.first as Map);
      }
      if (cached != null) {
        return BusinessInfoModel.fromMap(cached).toEntity();
      }
      return null;
    } catch (e, st) {
      LoggerService.w(
        'Fallo al leer business_info de caché',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<void> cacheBusinessInfo(BusinessInfoEntity info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = BusinessInfoModel.fromEntity(info).toMap();
      if (info.id != null) {
        payload['id'] = info.id;
      }
      await prefs.setString(_businessInfoCacheKey, jsonEncode(payload));
    } catch (e, st) {
      LoggerService.w(
        'Fallo al guardar business_info en caché',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<BusinessInfoEntity> saveBusinessInfo(BusinessInfoEntity info) async {
    try {
      final payload = BusinessInfoModel.fromEntity(info).toMap();
      String? finalId = info.id;

      // Si no tenemos ID en la entidad, buscamos el registro existente (patrón Singleton)
      if (finalId == null) {
        final checkDb = await _supabase
            .from('business_info')
            .select('id')
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (checkDb != null) {
          finalId = checkDb['id']?.toString();
        }
      }

      if (finalId != null) {
        payload['id'] = finalId;
        final response = await _supabase
            .from('business_info')
            .upsert(payload)
            .select(
              'id, business_name, tax_id, address, phone, logo_url, loyalty_global_enabled, loyalty_customer_visible',
            )
            .single();

        final savedEntity = BusinessInfoModel.fromMap(response).toEntity();
        await cacheBusinessInfo(savedEntity);
        return savedEntity;
      } else {
        final inserted = await _supabase
            .from('business_info')
            .insert(payload)
            .select(
              'id, business_name, tax_id, address, phone, logo_url, loyalty_global_enabled, loyalty_customer_visible',
            )
            .single();

        final savedEntity = BusinessInfoModel.fromMap(inserted).toEntity();
        await cacheBusinessInfo(savedEntity);
        return savedEntity;
      }
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error Postgrest al guardar business_info: ${e.message}',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.message, originalError: e);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al guardar business_info',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }

  @override
  Future<String> uploadBusinessLogo(Uint8List bytes) async {
    try {
      // Ruta canónica única con upsert para evitar la acumulación de archivos huérfanos
      const path = 'logos/business_logo.webp';
      await _supabase.storage.from('business').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/webp',
            ),
          );

      final baseUrl = _supabase.storage.from('business').getPublicUrl(path);
      // Cache buster controlado para refrescar inmediatamente en CachedNetworkImage sin crear archivos extra
      return '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    } on StorageException catch (e, st) {
      LoggerService.e(
        'Error de Supabase Storage al subir logo comercial: ${e.message}',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.message, originalError: e);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al subir logo comercial',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      throw AppException(message: e.toString(), originalError: e);
    }
  }

  @override
  Future<void> changeConnection(String url, String key) async {
    try {
      final authHealthUrl = Uri.parse('$url/auth/v1/health');
      final response = await http
          .get(authHealthUrl)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'El servidor no respondió correctamente (Status: ${response.statusCode})',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('SUPABASE_URL', url);
      await prefs.setString('SUPABASE_KEY', key);
      await prefs.setString('SUPABASE_ANON_KEY', key);
    } catch (e, st) {
      LoggerService.e(
        'Fallo al cambiar la conexión de Supabase',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<void> restoreDefaultConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('SUPABASE_URL');
      await prefs.remove('SUPABASE_ANON_KEY');
    } catch (e, st) {
      LoggerService.w(
        'Fallo al restaurar la conexión por defecto',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  @override
  Future<String?> getConnectionUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('SUPABASE_URL');
    } catch (e, st) {
      LoggerService.w(
        'Fallo al obtener connection url',
        tag: 'AppConfigRepository',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
