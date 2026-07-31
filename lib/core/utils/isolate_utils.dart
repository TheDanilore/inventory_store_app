import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

abstract class IsolateUtils {
  /// Ejecuta [computation] en un Isolate secundario en plataformas nativas (Android, iOS, Windows, macOS, Linux).
  /// En Flutter Web (`kIsWeb`), ejecuta [computation] de forma asíncrona en el hilo principal sin lanzar UnsupportedError.
  static Future<T> run<T>(FutureOr<T> Function() computation) async {
    if (kIsWeb) {
      return await computation();
    }
    return await Isolate.run(computation);
  }
}
