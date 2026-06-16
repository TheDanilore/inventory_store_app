import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfigProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  bool _disposed = false;

  final Map<String, double> _values = {};
  String? _businessInfoId;
  String _businessName = 'Cargando...';
  String _businessTaxId = '';
  String _businessAddress = '';
  String _businessPhone = '';
  String _businessLogoUrl = '';
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _businessInfoLoaded = false;
  bool _isSavingBusinessInfo = false;
  bool _isSavingSettings = false;

  Map<String, double> get values => Map.unmodifiable(_values);
  bool get isLoaded => _isLoaded;
  bool get isSavingBusinessInfo => _isSavingBusinessInfo;
  bool get isSavingSettings => _isSavingSettings;
  String get businessName => _businessName;
  String get businessTaxId => _businessTaxId;
  String get businessAddress => _businessAddress;
  String get businessPhone => _businessPhone;
  String get businessLogoUrl => _businessLogoUrl;

  double getDouble(String key, [double defaultValue = 0]) =>
      _values[key] ?? defaultValue;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadConfig({bool force = false}) async {
    if (_isLoading) return;
    if (_isLoaded && !force) return;

    _isLoading = true;
    final prefs = await SharedPreferences.getInstance();

    final cachedString = prefs.getString('cached_app_settings');
    if (cachedString != null) {
      try {
        final List decoded = jsonDecode(cachedString);
        for (final item in decoded) {
          final key = item['key'] as String?;
          final value = item['value'];
          if (key != null && value != null) {
            _values[key] = (value as num).toDouble();
          }
        }
        _isLoaded = true;
        _safeNotify();
      } catch (_) {}
    }

    try {
      final response = await _supabase
          .from('app_settings')
          .select('key, value');

      final nextValues = <String, double>{};
      for (final item in List<Map<String, dynamic>>.from(response)) {
        final key = item['key'] as String?;
        final value = item['value'];
        if (key != null && value != null) {
          nextValues[key] = (value as num).toDouble();
        }
      }
      _values
        ..clear()
        ..addAll(nextValues);
      _isLoaded = true;
      await prefs.setString('cached_app_settings', jsonEncode(response));
    } catch (e) {
      debugPrint('Error red AppSettings: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> loadBusinessInfo({bool force = false}) async {
    if (_businessInfoLoaded && !force) return;

    final prefs = await SharedPreferences.getInstance();

    final cachedString = prefs.getString('cached_business_info');
    if (cachedString != null) {
      try {
        final decoded = jsonDecode(cachedString);
        Map<String, dynamic>? cached;
        if (decoded is Map) {
          cached = Map<String, dynamic>.from(decoded);
        } else if (decoded is List && decoded.isNotEmpty) {
          cached = Map<String, dynamic>.from(decoded.first as Map);
        }
        if (cached != null) {
          _applyBusinessInfo(cached);
          _safeNotify();
        }
      } catch (_) {}
    }

    try {
      // CORRECCIÓN: Ordenamos de forma descendente por actualización por si existen registros duplicados huérfanos
      final rawResponse = await _supabase
          .from('business_info')
          .select('id, business_name, tax_id, address, phone, logo_url')
          .order('updated_at', ascending: false)
          .limit(1);

      Map<String, dynamic>? response;

      if (rawResponse.isNotEmpty) {
        response = rawResponse.first;
      }

      if (response != null) {
        _applyBusinessInfo(response);
        await prefs.setString('cached_business_info', jsonEncode(response));
      } else {
        _businessName = 'Sin configurar';
        _businessInfoLoaded = true;
      }
    } catch (e) {
      debugPrint('Error red BusinessInfo: $e');
    } finally {
      _safeNotify();
    }
  }

  void _applyBusinessInfo(Map<String, dynamic> data) {
    _businessInfoLoaded = true;
    _businessInfoId = data['id']?.toString();
    _businessName = data['business_name']?.toString() ?? 'Sin configurar';
    _businessTaxId = data['tax_id']?.toString() ?? '';
    _businessAddress = data['address']?.toString() ?? '';
    _businessPhone = data['phone']?.toString() ?? '';
    _businessLogoUrl = data['logo_url']?.toString() ?? '';
  }

  Future<bool> saveBusinessInfo({
    required String businessName,
    String? taxId,
    String? address,
    String? phone,
    String? logoUrl,
  }) async {
    if (_isSavingBusinessInfo) return false;
    _isSavingBusinessInfo = true;
    _safeNotify();

    try {
      final payload = <String, dynamic>{
        'business_name': businessName.trim(),
        'tax_id': taxId?.trim().isNotEmpty == true ? taxId!.trim() : null,
        'address': address?.trim().isNotEmpty == true ? address!.trim() : null,
        'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
        'logo_url': logoUrl?.trim().isNotEmpty == true ? logoUrl!.trim() : null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      payload.removeWhere((_, value) => value == null);

      // CORRECCIÓN MEDIDA DE SEGURIDAD: Si el ID local está vacío, verificamos si existe alguna fila en la BD
      // antes de arriesgarnos a un insert() para mitigar la creación de registros múltiples redundantes.
      if (_businessInfoId == null) {
        try {
          final checkDb =
              await _supabase
                  .from('business_info')
                  .select('id')
                  .order('updated_at', ascending: false)
                  .limit(1)
                  .maybeSingle();
          if (checkDb != null) {
            _businessInfoId = checkDb['id']?.toString();
          }
        } catch (_) {}
      }

      if (_businessInfoId != null) {
        await _supabase
            .from('business_info')
            .update(payload)
            .eq('id', _businessInfoId!);
      } else {
        final inserted =
            await _supabase
                .from('business_info')
                .insert(payload)
                .select('id')
                .maybeSingle();
        _businessInfoId = inserted?['id']?.toString();
      }

      _businessName =
          businessName.trim().isNotEmpty
              ? businessName.trim()
              : 'Sin configurar';
      _businessTaxId = taxId?.trim() ?? '';
      _businessAddress = address?.trim() ?? '';
      _businessPhone = phone?.trim() ?? '';
      _businessLogoUrl = logoUrl?.trim() ?? '';

      await loadBusinessInfo(force: true);
      return true;
    } catch (e) {
      debugPrint('Error saving BusinessInfo: $e');
      return false;
    } finally {
      _isSavingBusinessInfo = false;
      _safeNotify();
    }
  }

  Future<void> saveValue(
    String key,
    double value, {
    String? description,
  }) async {
    final payload = <String, dynamic>{'key': key, 'value': value};
    if (description != null && description.isNotEmpty) {
      payload['description'] = description;
    }
    await _supabase.from('app_settings').upsert(payload, onConflict: 'key');
    _values[key] = value;
    _safeNotify();
  }

  Future<bool> saveMultipleValues(
    Map<String, double> newValues, {
    Map<String, String>? descriptions,
  }) async {
    if (_isSavingSettings) return false;
    _isSavingSettings = true;
    _safeNotify();

    try {
      final List<Map<String, dynamic>> payloadList = [];

      for (final entry in newValues.entries) {
        final payload = <String, dynamic>{
          'key': entry.key,
          'value': entry.value,
        };
        if (descriptions != null && descriptions.containsKey(entry.key)) {
          payload['description'] = descriptions[entry.key];
        }
        payloadList.add(payload);
      }

      if (payloadList.isNotEmpty) {
        await _supabase.from('app_settings').upsert(payloadList, onConflict: 'key');
        _values.addAll(newValues);
      }
      
      return true;
    } catch (e) {
      debugPrint('Error saving multiple settings: $e');
      return false;
    } finally {
      _isSavingSettings = false;
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
