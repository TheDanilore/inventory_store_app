import 'app_notification.dart';

// ─────────────────────────────────────────────────────────────────────────
// Snapshots: el mínimo que necesitan las reglas. Mapea tus modelos reales
// (variante de producto y lote) a estos DTOs en tu InventoryAlertSource.
// ─────────────────────────────────────────────────────────────────────────

class StockVariantSnapshot {
  final String variantId;
  final String productName;
  final String? variantName;
  final int totalStock;

  /// Punto de reorden configurado en el producto/variante. null = usar el
  /// umbral por defecto de [InventoryAlertConfig.defaultLowStockThreshold].
  final int? reorderPoint;
  final bool isActive;

  /// Cuántos lotes de esta variante vencieron con stock en los últimos
  /// [InventoryAlertConfig.repeatedExpiryWindowDays] días (para sugerir
  /// descontinuar cuando se repite).
  final int recentExpiredLotCount;

  const StockVariantSnapshot({
    required this.variantId,
    required this.productName,
    required this.totalStock,
    this.variantName,
    this.reorderPoint,
    this.isActive = true,
    this.recentExpiredLotCount = 0,
  });

  String get displayName =>
      (variantName == null || variantName!.trim().isEmpty)
          ? productName
          : '$productName · $variantName';
}

class LotSnapshot {
  final String lotId;
  final String variantId;
  final String productName;
  final String? variantName;
  final String lotCode;
  final int quantity;
  final DateTime? expiresAt;

  const LotSnapshot({
    required this.lotId,
    required this.variantId,
    required this.productName,
    required this.lotCode,
    required this.quantity,
    this.variantName,
    this.expiresAt,
  });

  String get displayName =>
      (variantName == null || variantName!.trim().isEmpty)
          ? productName
          : '$productName · $variantName';
}

class InventoryAlertConfig {
  /// Stock bajo por defecto cuando no hay punto de reorden: 3 unidades.
  final int defaultLowStockThreshold;

  /// Días para avisar "próximo a vencer" (warning).
  final int expiryWarningDays;

  /// Días para escalar a crítico (acción comercial urgente).
  final int expiryCriticalDays;

  /// A partir de cuántos lotes vencidos repetidos se sugiere descontinuar.
  final int repeatedExpiryThreshold;
  final int repeatedExpiryWindowDays;
  final String inventoryRoute;
  final String exitsRoute;

  const InventoryAlertConfig({
    this.defaultLowStockThreshold = 3,
    this.expiryWarningDays = 30,
    this.expiryCriticalDays = 7,
    this.repeatedExpiryThreshold = 2,
    this.repeatedExpiryWindowDays = 180,
    this.inventoryRoute = '/inventory',
    this.exitsRoute = '/inventory-exits/form',
  });
}

/// Fuente de datos. Impleméntala sobre tus repositorios/use-cases reales.
abstract class InventoryAlertSource {
  Future<List<StockVariantSnapshot>> fetchVariants();
  Future<List<LotSnapshot>> fetchLots();
}

// ─────────────────────────────────────────────────────────────────────────
// Motor de reglas (función pura → fácil de testear)
// ─────────────────────────────────────────────────────────────────────────

class InventoryAlertEvaluator {
  final InventoryAlertConfig config;
  const InventoryAlertEvaluator([this.config = const InventoryAlertConfig()]);

  List<AppNotification> evaluate({
    required List<StockVariantSnapshot> variants,
    required List<LotSnapshot> lots,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();
    final today = DateTime(ts.year, ts.month, ts.day);
    final out = <AppNotification>[];

    // 1) Stock bajo / agotado ───────────────────────────────────────────
    for (final v in variants) {
      if (!v.isActive) continue;
      final threshold = v.reorderPoint ?? config.defaultLowStockThreshold;

      if (v.totalStock <= 0) {
        out.add(
          AppNotification(
            id: 'stock:${v.variantId}:out',
            kind: NotificationKind.outOfStock,
            severity: NotificationSeverity.critical,
            title: 'Sin stock: ${v.displayName}',
            message: 'Se agotó el stock. Repón para no perder ventas.',
            action: SuggestedAction.reorder,
            routePath:
                '${config.inventoryRoute}?search=${Uri.encodeComponent(v.productName)}',
            payload: {'variantId': v.variantId},
            createdAt: ts,
          ),
        );
      } else if (v.totalStock <= threshold) {
        out.add(
          AppNotification(
            id: 'stock:${v.variantId}:low',
            kind: NotificationKind.lowStock,
            severity: NotificationSeverity.warning,
            title: 'Stock bajo: ${v.displayName}',
            message:
                'Quedan ${v.totalStock} unid. (mínimo: $threshold'
                '${v.reorderPoint == null ? ', por defecto' : ''}).',
            action: SuggestedAction.reorder,
            routePath:
                '${config.inventoryRoute}?search=${Uri.encodeComponent(v.productName)}',
            payload: {'variantId': v.variantId},
            createdAt: ts,
          ),
        );
      }
    }

    // 2) Lotes vencidos / por vencer ────────────────────────────────────
    for (final l in lots) {
      final exp = l.expiresAt;
      if (exp == null || l.quantity <= 0) continue;
      final days =
          DateTime(exp.year, exp.month, exp.day).difference(today).inDays;

      // No inundar la bandeja con lotes vencidos hace más de 60 días
      if (days < -60) continue;

      if (days < 0) {
        out.add(
          AppNotification(
            id: 'lot:${l.lotId}:expired',
            kind: NotificationKind.lotExpired,
            severity: NotificationSeverity.critical,
            title: 'Lote vencido: ${l.displayName}',
            message:
                'Lote ${l.lotCode} venció hace ${-days} día(s) con '
                '${l.quantity} unid. Retíralo de la venta y regístralo como merma.',
            action: SuggestedAction.writeOff,
            routePath:
                '${config.exitsRoute}?batchId=${l.lotId}&variantId=${l.variantId}&reason=VENCIMIENTO',
            payload: {'lotId': l.lotId, 'variantId': l.variantId},
            createdAt: ts,
          ),
        );
      } else if (days <= config.expiryCriticalDays) {
        out.add(
          AppNotification(
            id: 'lot:${l.lotId}:d${config.expiryCriticalDays}',
            kind: NotificationKind.lotExpiringSoon,
            severity: NotificationSeverity.critical,
            title:
                'Vence ${days == 0 ? 'hoy' : 'en $days día(s)'}: ${l.displayName}',
            message:
                'Lote ${l.lotCode} · ${l.quantity} unid. Dale salida ya: '
                'promoción o descuento para evitar la merma.',
            action: SuggestedAction.discount,
            routePath:
                '${config.inventoryRoute}?tab=batches&filter=crítico&search=${Uri.encodeComponent(l.lotCode)}',
            payload: {'lotId': l.lotId, 'variantId': l.variantId},
            createdAt: ts,
          ),
        );
      } else if (days <= config.expiryWarningDays) {
        out.add(
          AppNotification(
            id: 'lot:${l.lotId}:d${config.expiryWarningDays}',
            kind: NotificationKind.lotExpiringSoon,
            severity: NotificationSeverity.warning,
            title: 'Próximo a vencer: ${l.displayName}',
            message:
                'Lote ${l.lotCode} vence en $days días (${l.quantity} unid.). '
                'Prioriza su salida (FEFO).',
            action: SuggestedAction.review,
            routePath:
                '${config.inventoryRoute}?tab=batches&filter=próximo&search=${Uri.encodeComponent(l.lotCode)}',
            payload: {'lotId': l.lotId, 'variantId': l.variantId},
            createdAt: ts,
          ),
        );
      }
    }

    // 3) Sugerencia de descontinuar (vencimientos repetidos) ────────────
    for (final v in variants) {
      if (v.isActive &&
          v.recentExpiredLotCount >= config.repeatedExpiryThreshold) {
        out.add(
          AppNotification(
            id: 'discontinue:${v.variantId}',
            kind: NotificationKind.discontinueSuggestion,
            severity: NotificationSeverity.warning,
            title: 'Considera descontinuar: ${v.displayName}',
            message:
                '${v.recentExpiredLotCount} lotes vencieron en los últimos '
                '${config.repeatedExpiryWindowDays} días. Rota poco: reduce el '
                'pedido o descontinúalo.',
            action: SuggestedAction.discontinue,
            routePath:
                '${config.inventoryRoute}?search=${Uri.encodeComponent(v.productName)}',
            payload: {'variantId': v.variantId},
            createdAt: ts,
          ),
        );
      }
    }

    out.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return out;
  }
}
