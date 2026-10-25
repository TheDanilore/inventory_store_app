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

  /// Emite una vibración real utilizando el servicio de hardware `Vibrator` en móviles,
  /// con fallback seguro a `HapticFeedback` si no hay motor disponible o en Web.
  static Future<void> vibrate({
    int durationMs = 65,
    int amplitude = 140,
  }) async {
    try {
      if (!kIsWeb) {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          final hasCustomAmplitude =
              await Vibration.hasCustomVibrationsSupport();
          if (hasCustomAmplitude == true) {
            await Vibration.vibrate(
              duration: durationMs,
              amplitude: amplitude.clamp(1, 255),
            );
            return;
          } else {
            await Vibration.vibrate(duration: durationMs);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint(
        '[AppFeedbackService] Fallback de vibración a HapticFeedback: $e',
      );
    }

    // Fallback a nivel de framework
    try {
      if (durationMs > 100) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
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
