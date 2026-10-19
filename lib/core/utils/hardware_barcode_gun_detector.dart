import 'package:flutter/services.dart';

/// Detector universal de disparos de pistola de códigos de barra (USB / Bluetooth HID).
///
/// Las pistolas de códigos de barras emulan un teclado físico que teclea a alta velocidad
/// (< 150ms entre caracteres) y culmina enviando la tecla `Enter`.
class HardwareBarcodeGunDetector {
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeystroke = DateTime.fromMillisecondsSinceEpoch(0);
  final void Function(String code)? onBarcodeScanned;

  HardwareBarcodeGunDetector({this.onBarcodeScanned});

  /// Procesa un [KeyEvent] y retorna el código escaneado si completó la lectura de la pistola,
  /// o `null` si aún está capturando o no es un disparo de pistola.
  String? onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return null;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    if (isAlt || isControl || isMeta) {
      _buffer.clear();
      return null;
    }

    final now = DateTime.now();
    final diffMs = now.difference(_lastKeystroke).inMilliseconds;
    _lastKeystroke = now;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_buffer.length >= 3 && diffMs < 200) {
        final code = _buffer.toString().trim();
        _buffer.clear();
        if (code.isNotEmpty) {
          onBarcodeScanned?.call(code);
          return code;
        }
      }
      _buffer.clear();
      return null;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      if (diffMs > 250) {
        _buffer.clear();
      }
      _buffer.write(char);
    }

    return null;
  }

  /// Conveniencia: retorna `true` si la tecla fue consumida como parte de un escaneo.
  bool handleKeyEvent(KeyEvent event) {
    return onKeyEvent(event) != null;
  }
}
