import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/features/app_config/data/models/business_info_model.dart';
import 'package:inventory_store_app/features/app_config/data/models/app_setting_model.dart';

import 'package:inventory_store_app/features/app_config/domain/repositories/app_config_repository.dart';

class AppConfigRepositoryImpl implements AppConfigRepository {
  final SupabaseClient _supabase;
  static const String _settingsCacheKey = 'cached_app_settings';
  static const String _businessInfoCacheKey = 'cached_business_info';

  AppConfigRepositoryImpl({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

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
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cacheAppSettings(List<Map<String, dynamic>> rawData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsCacheKey, jsonEncode(rawData));
    } catch (_) {}
  }
  
  @override
  Future<void> upsertAppSettings(List<AppSettingModel> settings) async {
    if (settings.isEmpty) return;
    final payloadList = settings.map((e) => e.toMap()).toList();
    await _supabase.from('app_settings').upsert(payloadList, onConflict: 'key');
  }

  // --- Business Info ---

  @override
  Future<BusinessInfoModel?> fetchBusinessInfo() async {
    final rawResponse = await _supabase
        .from('business_info')
        .select(
          'id, business_name, tax_id, address, phone, logo_url, loyalty_global_enabled, loyalty_customer_visible',
        )
        .order('updated_at', ascending: false)
        .limit(1);

    if (rawResponse.isNotEmpty) {
      return BusinessInfoModel.fromMap(rawResponse.first);
    }
    return null;
  }

  @override
  Future<BusinessInfoModel?> fetchCachedBusinessInfo() async {
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
        return BusinessInfoModel.fromMap(cached);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> cacheBusinessInfo(BusinessInfoModel info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = info.toMap();
      if (info.id != null) {
        payload['id'] = info.id; // Asegurar que el ID se guarde en caché
      }
      await prefs.setString(_businessInfoCacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  @override
  Future<BusinessInfoModel> saveBusinessInfo(BusinessInfoModel info) async {
    final payload = info.toMap();
    String? finalId = info.id;
    
    // Si no tenemos ID, verificamos primero si existe alguno en DB para no duplicar
    if (finalId == null) {
      try {
        final checkDb = await _supabase
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
      await _supabase
          .from('business_info')
          .update(payload)
          .eq('id', finalId);
    } else {
      final inserted = await _supabase
          .from('business_info')
          .insert(payload)
          .select('id')
          .maybeSingle();
      finalId = inserted?['id']?.toString();
    }
    
    return info.copyWith(id: finalId);
  }

  @override
  Future<String> uploadBusinessLogo(Uint8List bytes) async {
    final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}_${bytes.hashCode}.jpg';
    final path = 'logos/$fileName';
    await _supabase.storage.from('business').uploadBinary(path, bytes);
    return _supabase.storage.from('business').getPublicUrl(path);
  }
}
