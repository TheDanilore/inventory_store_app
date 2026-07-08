import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/core/models/business_info_model.dart';
import 'package:inventory_store_app/core/models/app_setting_model.dart';
import 'package:inventory_store_app/features/auth/data/repositories/app_config_repository.dart';

import 'package:inventory_store_app/core/enums/view_state.dart';

class AppConfigProvider extends ChangeNotifier {
  final AppConfigRepository _repository;
  bool _disposed = false;

  final Map<String, double> _values = {};
  BusinessInfoModel? _businessInfo;

  ViewState _settingsState = ViewState.initial;
  ViewState _businessInfoState = ViewState.initial;
  ViewState _saveState = ViewState.initial;

  AppConfigProvider({AppConfigRepository? repository})
      : _repository = repository ?? AppConfigRepository();

  Map<String, double> get values => Map.unmodifiable(_values);
  BusinessInfoModel? get businessInfo => _businessInfo;

  ViewState get settingsState => _settingsState;
  ViewState get businessInfoState => _businessInfoState;
  ViewState get saveState => _saveState;

  String get businessName => _businessInfo?.businessName ?? 'Sin configurar';
  String get businessTaxId => _businessInfo?.taxId ?? '';
  String get businessAddress => _businessInfo?.address ?? '';
  String get businessPhone => _businessInfo?.phone ?? '';
  String get businessLogoUrl => _businessInfo?.logoUrl ?? '';
  bool get loyaltyGlobalEnabled => _businessInfo?.loyaltyGlobalEnabled ?? true;
  bool get loyaltyCustomerVisible => _businessInfo?.loyaltyCustomerVisible ?? true;

  double getDouble(String key, [double defaultValue = 0]) =>
      _values[key] ?? defaultValue;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadConfig({bool force = false}) async {
    if (_settingsState == ViewState.loading) return;
    if (_settingsState == ViewState.success && !force) return;

    _settingsState = ViewState.loading;
    _safeNotify();

    // Try cache first
    final cached = await _repository.fetchCachedSettings();
    if (cached != null) {
      _values.addAll(cached);
      _settingsState = ViewState.success;
      _safeNotify();
    }

    try {
      final remoteValues = await _repository.fetchAppSettings();
      _values
        ..clear()
        ..addAll(remoteValues);
      
      // Update cache
      final rawData = remoteValues.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
      await _repository.cacheAppSettings(rawData);

      _settingsState = ViewState.success;
    } catch (e) {
      debugPrint('Error loading app settings: $e');
      if (cached == null) {
        _settingsState = ViewState.error;
      }
    } finally {
      if (_settingsState == ViewState.loading) {
        _settingsState = ViewState.error; // Should not reach here typically
      }
      _safeNotify();
    }
  }

  Future<void> loadBusinessInfo({bool force = false}) async {
    if (_businessInfoState == ViewState.loading) return;
    if (_businessInfoState == ViewState.success && !force) return;

    _businessInfoState = ViewState.loading;
    _safeNotify();

    final cached = await _repository.fetchCachedBusinessInfo();
    if (cached != null) {
      _businessInfo = cached;
      _businessInfoState = ViewState.success;
      _safeNotify();
    }

    try {
      final remoteInfo = await _repository.fetchBusinessInfo();
      if (remoteInfo != null) {
        _businessInfo = remoteInfo;
        await _repository.cacheBusinessInfo(remoteInfo);
        _businessInfoState = ViewState.success;
      } else {
        _businessInfo = const BusinessInfoModel(
          businessName: 'Sin configurar',
          taxId: '',
          address: '',
          phone: '',
          logoUrl: '',
          loyaltyGlobalEnabled: true,
          loyaltyCustomerVisible: true,
        );
        _businessInfoState = ViewState.empty;
      }
    } catch (e) {
      debugPrint('Error loading business info: $e');
      if (cached == null) {
         _businessInfoState = ViewState.error;
      }
    } finally {
      if (_businessInfoState == ViewState.loading) {
        _businessInfoState = ViewState.error;
      }
      _safeNotify();
    }
  }

  Future<bool> saveBusinessInfo({
    required String businessName,
    String? taxId,
    String? address,
    String? phone,
    String? logoUrl,
    bool? loyaltyGlobalEnabled,
    bool? loyaltyCustomerVisible,
  }) async {
    if (_saveState == ViewState.loading) return false;
    _saveState = ViewState.loading;
    _safeNotify();

    try {
      final newInfo = BusinessInfoModel(
        id: _businessInfo?.id,
        businessName: businessName.trim(),
        taxId: taxId?.trim() ?? '',
        address: address?.trim() ?? '',
        phone: phone?.trim() ?? '',
        logoUrl: logoUrl?.trim() ?? '',
        loyaltyGlobalEnabled: loyaltyGlobalEnabled ?? this.loyaltyGlobalEnabled,
        loyaltyCustomerVisible: loyaltyCustomerVisible ?? this.loyaltyCustomerVisible,
      );

      final savedInfo = await _repository.saveBusinessInfo(newInfo);
      _businessInfo = savedInfo;
      await _repository.cacheBusinessInfo(savedInfo);

      _saveState = ViewState.success;
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('Error saving business info: $e');
      _saveState = ViewState.error;
      _safeNotify();
      return false;
    }
  }

  Future<String?> uploadBusinessLogo(Uint8List bytes) async {
    if (_saveState == ViewState.loading) return null;
    _saveState = ViewState.loading;
    _safeNotify();

    try {
      final url = await _repository.uploadBusinessLogo(bytes);
      _saveState = ViewState.success;
      _safeNotify();
      return url;
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      _saveState = ViewState.error;
      _safeNotify();
      return null;
    }
  }

  Future<void> saveValue(
    String key,
    double value, {
    String? description,
  }) async {
    await saveMultipleValues(
      {key: value},
      descriptions: description != null ? {key: description} : null,
    );
  }

  Future<bool> saveMultipleValues(
    Map<String, double> newValues, {
    Map<String, String>? descriptions,
  }) async {
    if (_saveState == ViewState.loading) return false;
    _saveState = ViewState.loading;
    _safeNotify();

    try {
      final settings = newValues.entries.map((entry) {
        return AppSettingModel(
          key: entry.key,
          value: entry.value,
          description: descriptions?[entry.key],
        );
      }).toList();

      await _repository.upsertAppSettings(settings);
      _values.addAll(newValues);

      // Actualizar caché
      final rawData = _values.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
      await _repository.cacheAppSettings(rawData);

      _saveState = ViewState.success;
      _safeNotify();
      return true;
    } catch (e) {
      debugPrint('Error saving multiple settings: $e');
      _saveState = ViewState.error;
      _safeNotify();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
