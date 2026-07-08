import 'dart:typed_data';
import 'package:inventory_store_app/features/app_config/domain/entities/business_info_entity.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/app_setting_entity.dart';

/// Contrato del repositorio de configuración de la app.
abstract class AppConfigRepository {
  /// Obtiene la configuración general del sistema (tipo de cambio, IGV, etc.).
  Future<Map<String, double>> fetchAppSettings();

  /// Obtiene la configuración desde caché.
  Future<Map<String, double>?> fetchCachedSettings();

  /// Obtiene la información del negocio.
  Future<BusinessInfoEntity?> fetchBusinessInfo();

  /// Obtiene la información del negocio desde caché.
  Future<BusinessInfoEntity?> fetchCachedBusinessInfo();

  /// Guarda en caché la configuración de la app (raw).
  Future<void> cacheAppSettings(List<Map<String, dynamic>> rawData);

  /// Actualiza/Inserta configuraciones de la app.
  Future<void> upsertAppSettings(List<AppSettingEntity> settings);

  /// Guarda en caché la información del negocio.
  Future<void> cacheBusinessInfo(BusinessInfoEntity info);

  /// Guarda la información del negocio en remoto.
  Future<BusinessInfoEntity> saveBusinessInfo(BusinessInfoEntity info);

  /// Sube el logo del negocio a storage y devuelve la URL.
  Future<String> uploadBusinessLogo(Uint8List bytes);
}
