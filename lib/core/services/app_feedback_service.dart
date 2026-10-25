import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/barcode_scanner_hardware_service.dart';
import 'package:vibration/vibration.dart';

/// Servicio centralizado de retroalimentación física (Vibración / Háptico)
/// y auditiva (Bip de escáner / Sonidos de confirmación POS).
///
/// Resuelve las limitaciones nativas de Android donde:
/// 1. `HapticFeedback` es silenciado si el usuario apagó "Vibración al tocar" en Ajustes.
/// 2. `SystemSound.play` es silenciado si el celular está en modo vibración/silencio o sin sonidos táctiles.
class AppFeedbackService {
  AppFeedbackService._();

  static AudioPlayer? _audioPlayer;

  static AudioPlayer get _player {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.setReleaseMode(ReleaseMode.stop);
    }
    return _audioPlayer!;
  }

  static bool? _hasVibrator;
  static bool? _hasCustomAmplitude;

  /// Emite una vibración real utilizando el servicio de hardware `Vibrator` en móviles,
  /// con fallback seguro a `HapticFeedback` si no hay motor disponible o en Web.
  static Future<void> vibrate({int durationMs = 30, int amplitude = 64}) async {
    if (kIsWeb) {
      try {
        if (durationMs > 50) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      } catch (_) {}
      return;
    }

    try {
      _hasVibrator ??= await Vibration.hasVibrator();
      if (_hasVibrator == true) {
        _hasCustomAmplitude ??= await Vibration.hasCustomVibrationsSupport();
        if (_hasCustomAmplitude == true) {
          await Vibration.vibrate(
            duration: durationMs,
            amplitude: amplitude.clamp(1, 255),
          );
        } else {
          await Vibration.vibrate(duration: durationMs);
        }
        return;
      }
    } catch (e) {
      debugPrint('[AppFeedbackService] Fallback de vibración: $e');
    }

    // Fallback a nivel de framework
    try {
      if (durationMs > 50) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Vibración ligera (30ms, amp 64) para toques, botones y navegación.
  static void lightImpact() {
    vibrate(durationMs: 30, amplitude: 64);
  }

  /// Vibración media (50ms, amp 128) para confirmaciones, botones principales y escaneo.
  static void mediumImpact() {
    vibrate(durationMs: 50, amplitude: 128);
  }

  /// Vibración fuerte (70ms, amp 160) para advertencias, eliminaciones y operaciones críticas.
  static void heavyImpact() {
    vibrate(durationMs: 70, amplitude: 160);
  }

  /// Micro-vibración de selección (25ms, amp 60) para dropdowns, pestañas y chips.
  static void selectionClick() {
    vibrate(durationMs: 25, amplitude: 60);
  }

  /// Reproduce un tono de Bip real de escáner / caja registradora
  /// a través del canal multimedia (independiente de los sonidos táctiles de Android).
  static Future<void> playBeep({double volume = 0.85}) async {
    try {
      final player = _player;
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.stop();
      await player.play(AssetSource('sounds/scanner_beep.wav'));
    } catch (e) {
      debugPrint('[AppFeedbackService] Error reproduciendo bip de escáner: $e');
      // Fallback a sonido del sistema
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Dispara el feedback configurado en las preferencias del usuario para
  /// escaneo de productos, cobros y confirmaciones del POS.
  static Future<void> triggerFeedback({
    bool forceVibrate = false,
    bool forceSound = false,
  }) async {
    final shouldVibrate =
        forceVibrate || BarcodeScannerHardwareService.hapticNotifier.value;
    final shouldSound =
        forceSound || BarcodeScannerHardwareService.soundBeepNotifier.value;

    if (shouldVibrate) {
      vibrate();
    }
    if (shouldSound) {
      playBeep();
    }
  }
}
