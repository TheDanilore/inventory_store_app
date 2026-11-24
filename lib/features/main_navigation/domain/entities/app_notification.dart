import 'package:equatable/equatable.dart';

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

class AppNotification extends Equatable {
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'severity': severity.name,
    'title': title,
    'message': message,
    'action': action?.name,
    'route_path': routePath,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String? ?? NotificationKind.lowStock.name;
    final severityName =
        json['severity'] as String? ?? NotificationSeverity.warning.name;
    final actionName = json['action'] as String?;

    final rawPayload = json['payload'];
    final payloadMap =
        rawPayload is Map
            ? rawPayload.map((k, v) => MapEntry(k.toString(), v.toString()))
            : const <String, String>{};

    return AppNotification(
      id: json['id'] as String? ?? '',
      kind: NotificationKind.values.firstWhere(
        (e) => e.name == kindName,
        orElse: () => NotificationKind.lowStock,
      ),
      severity: NotificationSeverity.values.firstWhere(
        (e) => e.name == severityName,
        orElse: () => NotificationSeverity.warning,
      ),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      action:
          actionName == null
              ? null
              : SuggestedAction.values.firstWhere(
                (e) => e.name == actionName,
                orElse: () => SuggestedAction.review,
              ),
      routePath: json['route_path'] as String? ?? '/inventory',
      payload: payloadMap,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    severity,
    title,
    message,
    action,
    routePath,
    payload,
    createdAt,
  ];
}
