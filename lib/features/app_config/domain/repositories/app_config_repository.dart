import 'dart:typed_data';
import 'package:inventory_store_app/features/app_config/data/models/business_info_model.dart';
import 'package:inventory_store_app/features/app_config/data/models/app_setting_model.dart';

/// Contrato del repositorio de configuración de la app.
abstract class AppConfigRepository {
  /// Obtiene la configuración general del sistema (tipo de cambio, IGV, etc.).
  Future<Map<String, double>> fetchAppSettings();

  /// Obtiene la configuración desde caché.
  Future<Map<String, double>?> fetchCachedSettings();

  /// Obtiene la información del negocio.
  Future<BusinessInfoModel?> fetchBusinessInfo();

  /// Obtiene la información del negocio desde caché.
  Future<BusinessInfoModel?> fetchCachedBusinessInfo();

  /// Guarda en caché la configuración de la app (raw).
  Future<void> cacheAppSettings(List<Map<String, dynamic>> rawData);

  /// Actualiza/Inserta configuraciones de la app.
  Future<void> upsertAppSettings(List<AppSettingModel> settings);

  /// Guarda en caché la información del negocio.
  Future<void> cacheBusinessInfo(BusinessInfoModel info);

  /// Guarda la información del negocio en remoto.
  Future<BusinessInfoModel> saveBusinessInfo(BusinessInfoModel info);

  /// Sube el logo del negocio a storage y devuelve la URL.
  Future<String> uploadBusinessLogo(Uint8List bytes);
}
