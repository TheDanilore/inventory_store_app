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
  static bool _audioConfigured = false;

  static Future<AudioPlayer> _getPlayer() async {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      try {
        await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer!.setPlayerMode(PlayerMode.lowLatency);
      } catch (e) {
        debugPrint('[AppFeedbackService] Error en setPlayerMode: $e');
      }
    }
    if (!_audioConfigured) {
      _audioConfigured = true;
      try {
        await AudioPlayer.global.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: false,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.assistanceSonification,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: const {
                AVAudioSessionOptions.mixWithOthers,
                AVAudioSessionOptions.duckOthers,
              },
            ),
          ),
        );
      } catch (e) {
        debugPrint('[AppFeedbackService] Error configurando AudioContext: $e');
      }
    }
    return _audioPlayer!;
  }

  static bool? _hasVibrator;
  static bool? _hasCustomAmplitude;

  /// Emite una vibración real utilizando el servicio de hardware `Vibrator` en móviles,
  /// acompañado de `HapticFeedback` para garantizar respuesta física en cualquier dispositivo.
  static Future<void> vibrate({
    int durationMs = 80,
    int amplitude = 200,
  }) async {
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

    // Impacto háptico a nivel de sistema
    try {
      if (durationMs >= 75) {
        HapticFeedback.heavyImpact();
      } else if (durationMs >= 40) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}

    // Motor de vibración directo de Android / iOS
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
      }
    } catch (e) {
      debugPrint('[AppFeedbackService] Fallback de vibración: $e');
    }
  }

  /// Vibración ligera (35ms, amp 90) para toques, botones y navegación.
  static void lightImpact() {
    vibrate(durationMs: 35, amplitude: 90);
  }

  /// Vibración media (75ms, amp 180) para confirmaciones, botones principales y escaneo.
  static void mediumImpact() {
    vibrate(durationMs: 75, amplitude: 180);
  }

  /// Vibración fuerte (100ms, amp 240) para advertencias, eliminaciones y operaciones críticas.
  static void heavyImpact() {
    vibrate(durationMs: 100, amplitude: 240);
  }

  /// Micro-vibración de selección (30ms, amp 80) para dropdowns, pestañas y chips.
  static void selectionClick() {
    vibrate(durationMs: 30, amplitude: 80);
  }

  /// Reproduce un tono de Bip real de escáner / caja registradora
  /// a través del canal de sonificación (baja latencia y con fallback instantáneo).
  static Future<void> playBeep({double volume = 0.95}) async {
    try {
      // Disparo de sonido táctil de sistema inmediato
      SystemSound.play(SystemSoundType.click);

      final player = await _getPlayer();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.stop();
      await player.play(AssetSource('sounds/scanner_beep.wav'));
    } catch (e) {
      debugPrint('[AppFeedbackService] Error reproduciendo bip de escáner: $e');
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
      vibrate(durationMs: 90, amplitude: 220);
    }
    if (shouldSound) {
      playBeep();
    }
  }
}
