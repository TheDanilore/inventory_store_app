import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo que representa un equipo escáner / lector físico o integrado.
class ScannerDeviceModel {
  final String id;
  final String name;
  final String
  connectionType; // 'USB HID', 'Bluetooth', 'Inalámbrico 2.4G', 'Cámara Integrada'
  final String? brandOrModel;
  final DateTime? lastUsedAt;
  final bool isDefault;

  const ScannerDeviceModel({
    required this.id,
    required this.name,
    required this.connectionType,
    this.brandOrModel,
    this.lastUsedAt,
    this.isDefault = false,
  });

  ScannerDeviceModel copyWith({
    String? name,
    String? connectionType,
    String? brandOrModel,
    DateTime? lastUsedAt,
    bool? isDefault,
  }) {
    return ScannerDeviceModel(
      id: id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      brandOrModel: brandOrModel ?? this.brandOrModel,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'connectionType': connectionType,
    'brandOrModel': brandOrModel,
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'isDefault': isDefault,
  };

  factory ScannerDeviceModel.fromJson(Map<String, dynamic> json) {
    return ScannerDeviceModel(
      id: json['id'] as String? ?? 'scanner_def',
      name: json['name'] as String? ?? 'Lector USB / Bluetooth',
      connectionType: json['connectionType'] as String? ?? 'USB HID',
      brandOrModel: json['brandOrModel'] as String?,
      lastUsedAt:
          json['lastUsedAt'] != null
              ? DateTime.tryParse(json['lastUsedAt'] as String)
              : null,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// Registro de una lectura diagnóstica en tiempo real.
class ScannerDiagnosticLog {
  final String code;
  final DateTime timestamp;
  final int length;
  final int averageSpeedMs;
  final String suffix;

  const ScannerDiagnosticLog({
    required this.code,
    required this.timestamp,
    required this.length,
    required this.averageSpeedMs,
    required this.suffix,
  });
}

/// Servicio centralizado para gestionar las configuraciones de lectores,
/// pistolas de códigos de barras y cámaras de escaneo.
class BarcodeScannerHardwareService {
  static const String _keyDevices = 'scanner_registered_devices';
  static const String _keyAutoAdd = 'scanner_setting_auto_add';
  static const String _keySoundBeep = 'scanner_setting_sound_beep';
  static const String _keyHapticFeedback = 'scanner_setting_haptic_feedback';
  static const String _keyBurstThresholdMs =
      'scanner_setting_burst_threshold_ms';

  static final ValueNotifier<List<ScannerDeviceModel>> devicesNotifier =
      ValueNotifier<List<ScannerDeviceModel>>([]);
  static final ValueNotifier<bool> autoAddNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> soundBeepNotifier = ValueNotifier<bool>(
    true,
  );
  static final ValueNotifier<bool> hapticNotifier = ValueNotifier<bool>(true);
  static final ValueNotifier<int> burstThresholdNotifier = ValueNotifier<int>(
    160,
  );
  static final ValueNotifier<List<ScannerDiagnosticLog>> recentLogsNotifier =
      ValueNotifier<List<ScannerDiagnosticLog>>([]);

  static bool _initialized = false;

  /// Carga la configuración inicial desde SharedPreferences.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      autoAddNotifier.value = prefs.getBool(_keyAutoAdd) ?? true;
      soundBeepNotifier.value = prefs.getBool(_keySoundBeep) ?? true;
      hapticNotifier.value = prefs.getBool(_keyHapticFeedback) ?? true;
      burstThresholdNotifier.value = prefs.getInt(_keyBurstThresholdMs) ?? 160;

      final rawDevices = prefs.getString(_keyDevices);
      if (rawDevices != null && rawDevices.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawDevices) as List<dynamic>;
        devicesNotifier.value =
            decoded
                .map(
                  (e) => ScannerDeviceModel.fromJson(e as Map<String, dynamic>),
                )
                .toList();
      } else {
        // Dispositivos base por defecto para el sistema
        final defaultDevices = [
          ScannerDeviceModel(
            id: 'dev_primary_gun',
            name: 'Pistola Láser USB / BT Principal',
            connectionType: 'USB HID',
            brandOrModel: 'Universal Plug & Play',
            lastUsedAt: DateTime.now().subtract(const Duration(minutes: 5)),
            isDefault: true,
          ),
          ScannerDeviceModel(
            id: 'dev_mobile_cam',
            name: 'Cámara Móvil / Webcam POS',
            connectionType: 'Cámara Integrada',
            brandOrModel: 'Sensor CMOS 1080p',
            lastUsedAt: DateTime.now().subtract(const Duration(hours: 1)),
            isDefault: false,
          ),
        ];
        devicesNotifier.value = defaultDevices;
        await _saveDevices(prefs, defaultDevices);
      }
    } catch (e) {
      debugPrint(
        '[BarcodeScannerHardwareService] Error cargando preferencias: $e',
      );
    }
  }

  static Future<void> _saveDevices(
    SharedPreferences prefs,
    List<ScannerDeviceModel> list,
  ) async {
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyDevices, encoded);
  }

  /// Añade un nuevo equipo a la lista de dispositivos reconocidos.
  static Future<void> addDevice(ScannerDeviceModel device) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = List<ScannerDeviceModel>.from(devicesNotifier.value);

    // Si viene como predeterminado, desmarcar los demás
    if (device.isDefault) {
      for (int i = 0; i < updated.length; i++) {
        updated[i] = updated[i].copyWith(isDefault: false);
      }
    }

    updated.add(device);
    devicesNotifier.value = updated;
    await _saveDevices(prefs, updated);
  }

  /// Actualiza un equipo existente.
  static Future<void> updateDevice(ScannerDeviceModel device) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = List<ScannerDeviceModel>.from(devicesNotifier.value);
    final idx = updated.indexWhere((d) => d.id == device.id);
    if (idx != -1) {
      if (device.isDefault) {
        for (int i = 0; i < updated.length; i++) {
          updated[i] = updated[i].copyWith(isDefault: false);
        }
      }
      updated[idx] = device;
      devicesNotifier.value = updated;
      await _saveDevices(prefs, updated);
    }
  }

  /// Elimina un equipo.
  static Future<void> removeDevice(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = devicesNotifier.value.where((d) => d.id != id).toList();
    if (updated.isNotEmpty && !updated.any((d) => d.isDefault)) {
      updated[0] = updated[0].copyWith(isDefault: true);
    }
    devicesNotifier.value = updated;
    await _saveDevices(prefs, updated);
  }

  /// Registra que hubo actividad de escaneo y actualiza el dispositivo activo.
  static Future<void> recordScan({
    required String code,
    int averageSpeedMs = 15,
    String suffix = 'Enter',
  }) async {
    // 1. Efectos sonoros y hápticos
    triggerScanFeedback();

    // 2. Diagnóstico
    final newLog = ScannerDiagnosticLog(
      code: code,
      timestamp: DateTime.now(),
      length: code.length,
      averageSpeedMs: averageSpeedMs,
      suffix: suffix,
    );
    final logs = List<ScannerDiagnosticLog>.from(recentLogsNotifier.value);
    logs.insert(0, newLog);
    if (logs.length > 25) logs.removeLast();
    recentLogsNotifier.value = logs;

    // 3. Actualizar fecha de uso del equipo predeterminado
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = List<ScannerDeviceModel>.from(devicesNotifier.value);
      final defIdx = updated.indexWhere((d) => d.isDefault);
      if (defIdx != -1) {
        updated[defIdx] = updated[defIdx].copyWith(lastUsedAt: DateTime.now());
        devicesNotifier.value = updated;
        await _saveDevices(prefs, updated);
      }
    } catch (_) {}
  }

  /// Emite feedback háptico y sonoro si están habilitados en los ajustes.
  static void triggerScanFeedback() {
    AppFeedbackService.triggerFeedback();
  }

  /// Modifica el ajuste de adición automática.
  static Future<void> setAutoAdd(bool value) async {
    autoAddNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoAdd, value);
  }

  /// Modifica el ajuste de sonido de bip.
  static Future<void> setSoundBeep(bool value) async {
    soundBeepNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundBeep, value);
  }

  /// Modifica el ajuste de vibración.
  static Future<void> setHapticFeedback(bool value) async {
    hapticNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHapticFeedback, value);
  }

  /// Modifica el umbral de ráfaga para pistolas de código de barras.
  static Future<void> setBurstThresholdMs(int value) async {
    burstThresholdNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBurstThresholdMs, value);
  }
}
