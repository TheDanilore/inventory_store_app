import 'package:flutter/foundation.dart';

/// Helper centralizado para generar etiquetas de atajos de teclado adaptativas
/// según la plataforma (macOS / iOS usan ⌘, Windows / Web / Linux usan Ctrl).
class AppShortcutLabels {
  AppShortcutLabels._();

  static bool get isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// En Web, navegadores (Chrome, Edge, Firefox) capturan Ctrl+K, Ctrl+1..4, Ctrl+H, Ctrl+T.
  /// La convención universal e inmune al navegador en Web es 'Alt'.
  static String get mod => kIsWeb ? 'Alt' : (isApple ? '⌘' : 'Ctrl');

  /// Prefijo con signo '+': 'Alt+', '⌘+' o 'Ctrl+'
  static String get modPlus => kIsWeb ? 'Alt+' : (isApple ? '⌘+' : 'Ctrl+');

  /// Etiqueta compacta de búsqueda: 'Alt K', '⌘K' o 'Ctrl K'
  static String get search => kIsWeb ? 'Alt K' : (isApple ? '⌘K' : 'Ctrl K');

  /// Etiqueta con signo: 'Alt+K', '⌘+K' o 'Ctrl+K'
  static String get searchPlus => kIsWeb ? 'Alt+K' : (isApple ? '⌘+K' : 'Ctrl+K');

  /// Etiqueta para nuevo registro: 'Alt+N', '⌘+N' o 'Ctrl+N'
  static String get newRecord => kIsWeb ? 'Alt+N' : (isApple ? '⌘+N' : 'Ctrl+N');

  /// Etiqueta para alternar vistas: 'Alt+V', '⌘+V' o 'Ctrl+V'
  static String get toggleView => kIsWeb ? 'Alt+V' : (isApple ? '⌘+V' : 'Ctrl+V');

  /// Etiqueta para atajos numéricos de pestañas: 'Alt+1', '⌘+1' o 'Ctrl+1'
  static String tab(int index) =>
      kIsWeb ? 'Alt+$index' : (isApple ? '⌘+$index' : 'Ctrl+$index');
}
