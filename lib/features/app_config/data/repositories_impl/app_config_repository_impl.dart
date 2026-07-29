import 'package:injectable/injectable.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
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
    final response = await _supabase.from('app_settings').select('key, value');

    final values = <String, double>{};
    for (final item in List<Map<String, dynamic>>.from(response)) {
      final key = item['key'] as String?;
      final value = item['value'];
      if (key != null && value != null) {
        values[key] = (value as num).toDouble();
      }
    }
    return values;
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
    } catch (e) {
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<void> cacheAppSettings(List<Map<String, dynamic>> rawData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsCacheKey, jsonEncode(rawData));
    } catch (e) {
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<void> upsertAppSettings(List<AppSettingEntity> settings) async {
    if (settings.isEmpty) return;
    final payloadList =
        settings.map((e) => AppSettingModel.fromEntity(e).toMap()).toList();
    await _supabase.from('app_settings').upsert(payloadList, onConflict: 'key');
  }

  // --- Business Info ---

  @override
  Future<BusinessInfoEntity?> fetchBusinessInfo() async {
    final rawResponse = await _supabase
        .from('business_info')
        .select(
          'id, business_name, tax_id, address, phone, logo_url, loyalty_global_enabled, loyalty_customer_visible',
        )
        .order('updated_at', ascending: false)
        .limit(1);

    if (rawResponse.isNotEmpty) {
      return BusinessInfoModel.fromMap(rawResponse.first).toEntity();
    }
    return null;
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
    } catch (e) {
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<void> cacheBusinessInfo(BusinessInfoEntity info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = BusinessInfoModel.fromEntity(info).toMap();
      if (info.id != null) {
        payload['id'] = info.id; // Asegurar que el ID se guarde en caché
      }
      await prefs.setString(_businessInfoCacheKey, jsonEncode(payload));
    } catch (e) {
      throw CacheException(originalError: e);
    }
  }

  @override
  Future<BusinessInfoEntity> saveBusinessInfo(BusinessInfoEntity info) async {
    final payload = BusinessInfoModel.fromEntity(info).toMap();
    String? finalId = info.id;

    // Si no tenemos ID, verificamos primero si existe alguno en DB para no duplicar
    if (finalId == null) {
      try {
        final checkDb =
            await _supabase
                .from('business_info')
                .select('id')
                .order('updated_at', ascending: false)
                .limit(1)
                .maybeSingle();
        if (checkDb != null) {
          finalId = checkDb['id']?.toString();
        }
      } catch (_) {}
    }

    if (finalId != null) {
      await _supabase.from('business_info').update(payload).eq('id', finalId);
    } else {
      final inserted =
          await _supabase
              .from('business_info')
              .insert(payload)
              .select('id')
              .maybeSingle();
      finalId = inserted?['id']?.toString();
    }

    return BusinessInfoModel.fromEntity(info).copyWith(id: finalId).toEntity();
  }

  @override
  Future<String> uploadBusinessLogo(Uint8List bytes) async {
    final fileName =
        'logo_${DateTime.now().millisecondsSinceEpoch}_${bytes.hashCode}.jpg';
    final path = 'logos/$fileName';
    await _supabase.storage.from('business').uploadBinary(path, bytes);
    return _supabase.storage.from('business').getPublicUrl(path);
  }

  @override
  Future<void> changeConnection(String url, String key) async {
    final authHealthUrl = Uri.parse('$url/auth/v1/health');
    final response = await http
        .get(authHealthUrl)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Tiempo de espera agotado'),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'El servidor no respondió correctamente o la URL es inválida (Status: ${response.statusCode})',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('SUPABASE_URL', url);
    await prefs.setString('SUPABASE_KEY', key);
    await prefs.setString('SUPABASE_ANON_KEY', key);
  }

  @override
  Future<void> restoreDefaultConnection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('SUPABASE_URL');
    await prefs.remove('SUPABASE_ANON_KEY');
  }

  @override
  Future<String?> getConnectionUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('SUPABASE_URL');
  }
}
