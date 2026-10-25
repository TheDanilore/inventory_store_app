/// Entidad de notificación del sistema. Es independiente de la UI y del
/// backend: las reglas (ver inventory_alert_rules.dart) las generan y el
/// cubit las gestiona (leídas / descartadas).
enum NotificationSeverity { info, warning, critical }

enum NotificationKind {
  outOfStock,
  lowStock,
  lotExpiringSoon,
  lotExpired,
  discontinueSuggestion,
}

/// Acción sugerida por el sistema para resolver la alerta.
enum SuggestedAction {
  reorder, // Reponer / crear orden de compra
  discount, // Liquidar con promoción (salida comercial antes de vencer)
  writeOff, // Dar de baja como merma
  discontinue, // Descontinuar producto/variante
  review, // Revisar (FEFO, ubicar el lote, etc.)
}

extension SuggestedActionLabel on SuggestedAction {
  String get label => switch (this) {
    SuggestedAction.reorder => 'Reponer stock',
    SuggestedAction.discount => 'Liquidar con descuento',
    SuggestedAction.writeOff => 'Dar de baja (merma)',
    SuggestedAction.discontinue => 'Descontinuar',
    SuggestedAction.review => 'Revisar lote',
  };
}

class AppNotification {
  /// Id determinístico: el mismo problema genera siempre el mismo id, así
  /// "leída/descartada" sobrevive a los refrescos. Cuando la situación
  /// escala (p. ej. de "vence en 30 días" a "vence en 7 días") el id
  /// cambia y la alerta vuelve a aparecer como no leída.
  final String id;
  final NotificationKind kind;
  final NotificationSeverity severity;
  final String title;
  final String message;
  final SuggestedAction? action;

  /// Ruta de go_router a la que lleva la acción (ajústala a tus rutas).
  final String routePath;

  /// Datos para pre-cargar la pantalla destino (productId, lotId, etc.).
  final Map<String, String> payload;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.message,
    required this.routePath,
    required this.createdAt,
    this.action,
    this.payload = const {},
  });
}
