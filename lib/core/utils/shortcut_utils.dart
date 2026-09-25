import 'package:flutter/foundation.dart';

/// Helper centralizado para generar etiquetas de atajos de teclado adaptativas
/// según la plataforma (macOS / iOS usan ⌘, Windows / Web / Linux usan Ctrl).
class AppShortcutLabels {
  AppShortcutLabels._();

  static bool get isApple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Prefijo del modificador principal: '⌘' o 'Ctrl'
  static String get mod => isApple ? '⌘' : 'Ctrl';

  /// Prefijo con signo '+': '⌘+' o 'Ctrl+'
  static String get modPlus => isApple ? '⌘+' : 'Ctrl+';

  /// Etiqueta compacta de búsqueda: '⌘K' o 'Ctrl K'
  static String get search => isApple ? '⌘K' : 'Ctrl K';

  /// Etiqueta con signo: '⌘+K' o 'Ctrl+K'
  static String get searchPlus => isApple ? '⌘+K' : 'Ctrl+K';

  /// Etiqueta para nuevo registro: '⌘+N' o 'Ctrl+N'
  static String get newRecord => isApple ? '⌘+N' : 'Ctrl+N';

  /// Etiqueta para alternar vistas: '⌘+V' o 'Ctrl+V'
  static String get toggleView => isApple ? '⌘+V' : 'Ctrl+V';

  /// Etiqueta para atajos numéricos de pestañas: '⌘+1', 'Ctrl+1'
  static String tab(int index) => isApple ? '⌘+$index' : 'Ctrl+$index';
}
